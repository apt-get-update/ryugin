import QtQuick
import QtTest
import "../../qml"

TestCase {
    name: "Theme"

    function initTestCase() {
        Qt.application.organization = "ryugin-tests";
        Qt.application.domain = "tests";
    }

    function test_time_data() {
        return [
            { tag: "zero", s: 0, want: "0:00" },
            { tag: "seconds", s: 9, want: "0:09" },
            { tag: "minutes", s: 245, want: "4:05" },
            { tag: "fraction", s: 245.9, want: "4:05" },
            { tag: "hour", s: 3725, want: "1:02:05" },
            { tag: "negative", s: -5, want: "0:00" }
        ];
    }
    function test_time(d) {
        compare(Theme.time(d.s), d.want);
    }

    function test_follows_vivid_cover() {
        Theme.settings.followCover = true;
        Theme.seed = "#3060c0";
        compare(Theme.tone, Qt.color("#3060c0"));
    }
    function test_grey_cover_falls_back_to_gold() {
        Theme.settings.followCover = true;
        Theme.seed = "#777777";
        compare(Theme.tone, Theme.fallback);
    }
    function test_switch_off_keeps_gold() {
        Theme.seed = "#3060c0";
        Theme.settings.followCover = false;
        compare(Theme.tone, Theme.fallback);
        Theme.settings.followCover = true;
    }
    function test_fade_keeps_its_colour() {
        // From blue to green the UI never turns grey or red on the way.
        Theme.seed = "#3060c0";
        wait(900);
        Theme.seed = "#20a040";
        for (let i = 0; i < 8; i++) {
            wait(100);
            verify(Theme.s > 0.4, "saturation " + Theme.s);
            verify(Theme.h > 0.35 && Theme.h < 0.65, "hue " + Theme.h);
        }
    }
    function test_text_reads_on_background() {
        // Text must stay much lighter than the background, whatever the hue.
        for (const seed of ["#e2b55e", "#3060c0", "#c02020", "#20a040"]) {
            Theme.seed = seed;
            wait(900); // the fade
            verify(Theme.text.hslLightness - Theme.bg.hslLightness > 0.7, seed);
            verify(Theme.gold.hslLightness > Theme.card.hslLightness + 0.4, seed);
        }
    }
}
