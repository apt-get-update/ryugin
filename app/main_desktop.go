//go:build !silica

package main

import (
	"fmt"
	"io/fs"
	"log"
	"maps"
	"os"
	"os/signal"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
	"syscall"

	qt "github.com/mappu/miqt/qt6"
	"github.com/mappu/miqt/qt6/mainthread"
)

func main() {
	if running() {
		return
	}
	startQt()
	log.Println("start, pid", os.Getpid())
	// $RYUGIN_QML, next to the binary, or the installed copy.
	exe, _ := os.Executable()
	dir := qmlDir("Main.qml", os.Getenv("RYUGIN_QML"), filepath.Join(filepath.Dir(exe), "qml"), "/usr/share/"+appID+"/qml")
	translate(filepath.Join(dir, "translations"))
	iconDir, iconNames = themeIcons(dir)
	root, bridge := loadQML(dir)
	send := sender(root)

	_, hasTray := newTray(dir, send)
	root.SetProperty("hasTray", qt.NewQVariant8(hasTray))
	newMenuBar(send)
	bridge.OnObjectNameChanged(fromQML(startMpris(send), send))

	// SIGTERM (a logout, tests/run.sh) quits cleanly.
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGTERM, os.Interrupt)
	go func() { log.Println("quit:", <-quit); mainthread.Start(qt.QCoreApplication_Quit) }()

	qt.QGuiApplication_Exec()
	log.Println("exit")
}

// The sizes Icon.qml asks for, in pixels: themeIcons draws each one.
const iconMin, iconMax = 10, 64

// themeIcons draws each icon Icons.qml takes from the desktop's icon theme, from its SVG, as
// a PNG per size (iconMin to iconMax) in the cache, once: QML only shows ready pictures,
// sharp at their size (one resized was a blur), and nothing to draw while the app runs
// (an icon looked up in the theme by each Icon took a page ~0.7 s more). It returns their
// folder and the names drawn.
func themeIcons(qmlDir string) (string, string) {
	src, err := os.ReadFile(filepath.Join(qmlDir, "Icons.qml"))
	theme := qt.QIcon_ThemeName()
	if err != nil || theme == "" {
		return "", ""
	}
	cache, _ := os.UserCacheDir()
	dir := filepath.Join(cache, appID, "icons", theme)
	_ = os.MkdirAll(dir, 0o755) // none: no PNG saved, so QML draws Lucide's
	var names []string
	for name, svg := range themeSVGs(theme, themeNames(string(src))) {
		names = append(names, name)
		drawIcon(svg, filepath.Join(dir, name))
	}
	return dir, strings.Join(names, " ")
}

// themeNames: the theme names in Icons.qml's theme map ("lucide-name": "theme-name"), none
// found yet.
func themeNames(src string) map[string]string {
	if i := strings.Index(src, "property var theme:"); i >= 0 {
		src = src[i:]
	}
	if i := strings.Index(src, "})"); i >= 0 {
		src = src[:i]
	}
	names := map[string]string{}
	for _, m := range regexp.MustCompile(`": "([a-z0-9-]+)"`).FindAllStringSubmatch(src, -1) {
		names[m[1]] = ""
	}
	return names
}

// themeSVGs finds each name's SVG: in the theme, then in the ones it inherits while some are
// missing, a symbolic one first. It returns the names found.
func themeSVGs(theme string, found map[string]string) map[string]string {
	themes := []string{theme}
	// Up the inherited themes only while names are missing (the next one can be big).
	for i := 0; i < len(themes) && slices.Contains(slices.Collect(maps.Values(found)), ""); i++ {
		for _, base := range qt.QIcon_ThemeSearchPaths() {
			dir := filepath.Join(base, themes[i])
			themes = inherit(themes, dir)
			_ = filepath.WalkDir(dir, pickSVG(found))
		}
	}
	for name, path := range found {
		if path == "" {
			delete(found, name)
		}
	}
	return found
}

// pickSVG keeps, for each name in found, its SVG met while walking a theme: the first, or
// a symbolic one.
func pickSVG(found map[string]string) fs.WalkDirFunc {
	return func(path string, _ fs.DirEntry, err error) error {
		name := strings.TrimSuffix(filepath.Base(path), ".svg")
		if was, ok := found[name]; err == nil && ok && strings.HasSuffix(path, ".svg") &&
			(was == "" || strings.Contains(path, "/symbolic/") && !strings.Contains(was, "/symbolic/")) {
			found[name] = path
		}
		return nil
	}
}

// inherit adds the themes the one in dir inherits (its index.theme) to themes.
func inherit(themes []string, dir string) []string {
	for _, t := range strings.Split(readIni(filepath.Join(dir, "index.theme"))["Icon Theme"]["Inherits"], ",") {
		if t = strings.TrimSpace(t); t != "" && !slices.Contains(themes, t) {
			themes = append(themes, t)
		}
	}
	return themes
}

// drawIcon draws an SVG at each size as base@<px>.png, but those drawn since it changed.
func drawIcon(svg, base string) {
	icon := qt.NewQIcon4(svg)
	changed, _ := os.Stat(svg)
	for px := iconMin; px <= iconMax; px++ {
		png := fmt.Sprintf("%s@%d.png", base, px)
		if done, err := os.Stat(png); err == nil && done.ModTime().After(changed.ModTime()) {
			continue
		}
		icon.Pixmap(qt.NewQSize2(px, px)).Save(png)
	}
}

// startQt makes the Qt application: names, 8 bits per colour, the desktop's controls.
func startQt() {
	qtSetup()
	qt.NewQApplication(os.Args) // widgets, for the tray icon and the desktop's style
	desktopStyle()
	kdePalette()
}

// desktopStyle draws the controls with the desktop's widget style (Kvantum, Breeze...)
// through KDE's org.kde.desktop Qt Quick style, when installed and none is chosen.
func desktopStyle() {
	dir := filepath.Join(qt.QLibraryInfo_Path(qt.QLibraryInfo__QmlImportsPath), "org/kde/desktop")
	if _, err := os.Stat(dir); err == nil && os.Getenv("QT_QUICK_CONTROLS_STYLE") == "" {
		_ = os.Setenv("QT_QUICK_CONTROLS_STYLE", "org.kde.desktop")
	}
}

// kdePalette gives the app the desktop's KDE colour scheme (qt6ct's, or kdeglobals'), as
// Dolphin's KColorSchemeManager does: else the widget style (Kvantum) puts its own colours,
// a blue its theme set for other desktops.
func kdePalette() {
	path := qt.QCoreApplication_Instance().Property("KDE_COLOR_SCHEME_PATH").ToString()
	if path == "" {
		home, _ := os.UserHomeDir()
		cfg, _ := os.UserConfigDir()
		if name := readIni(filepath.Join(cfg, "kdeglobals"))["General"]["ColorScheme"]; name != "" {
			for _, dir := range []string{filepath.Join(home, ".local/share/color-schemes"), "/usr/share/color-schemes"} {
				if _, err := os.Stat(filepath.Join(dir, name+".colors")); err == nil {
					path = filepath.Join(dir, name+".colors")
					break
				}
			}
		}
	}
	scheme := readIni(path)
	if len(scheme) == 0 {
		return
	}
	pal := qt.QGuiApplication_Palette()
	for _, r := range []struct {
		role       qt.QPalette__ColorRole
		group, key string
	}{
		{qt.QPalette__Window, "Colors:Window", "BackgroundNormal"}, {qt.QPalette__WindowText, "Colors:Window", "ForegroundNormal"},
		{qt.QPalette__Base, "Colors:View", "BackgroundNormal"}, {qt.QPalette__AlternateBase, "Colors:View", "BackgroundAlternate"},
		{qt.QPalette__Text, "Colors:View", "ForegroundNormal"}, {qt.QPalette__PlaceholderText, "Colors:View", "ForegroundInactive"},
		{qt.QPalette__Link, "Colors:View", "ForegroundLink"},
		{qt.QPalette__Button, "Colors:Button", "BackgroundNormal"}, {qt.QPalette__ButtonText, "Colors:Button", "ForegroundNormal"},
		{qt.QPalette__Highlight, "Colors:Selection", "BackgroundNormal"}, {qt.QPalette__HighlightedText, "Colors:Selection", "ForegroundNormal"},
		{qt.QPalette__ToolTipBase, "Colors:Tooltip", "BackgroundNormal"}, {qt.QPalette__ToolTipText, "Colors:Tooltip", "ForegroundNormal"},
	} {
		var red, green, blue int
		if _, err := fmt.Sscanf(scheme[r.group][r.key], "%d,%d,%d", &red, &green, &blue); err == nil {
			pal.SetColor2(r.role, qt.NewQColor3(red, green, blue))
		}
	}
	qt.QApplication_SetPalette(pal)
}

// readIni reads an INI file as group -> key -> value; empty when it cannot.
func readIni(path string) map[string]map[string]string {
	out := map[string]map[string]string{}
	b, err := os.ReadFile(path)
	if path == "" || err != nil {
		return out
	}
	group := ""
	for _, line := range strings.Split(string(b), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]") {
			group = line[1 : len(line)-1]
		} else if k, v, ok := strings.Cut(line, "="); ok {
			if out[group] == nil {
				out[group] = map[string]string{}
			}
			out[group][k] = v
		}
	}
	return out
}
