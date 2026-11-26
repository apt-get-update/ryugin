//go:build silica

// Keel (Silica on Qt 6, Sailfish OS): its SailfishApp makes the application and the
// window, in direct mode (no qt-runner): Lipstick shows the window and its cover.
#include <QFont>
#include <QGuiApplication>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickView>
#include <QUrl>
#include <sailfishapp.h>

#include "silica.h"

static QQuickView *view;

void silica_application(int *argc, char **argv)
{
    SailfishApp::application(*argc, argv);
}

void *silica_view(void)
{
    view = SailfishApp::createView();
    // The card's close: Keel calls Qt.quit(). Out of the event loop at once, as Keel's own
    // SIGTERM does: QCoreApplication::quit() first closes the windows, Keel refuses the close
    // and asks to quit again, round and round (the app never died).
    QObject::connect(view->engine(), &QQmlEngine::quit, qApp, [] { QCoreApplication::exit(0); }, Qt::QueuedConnection);
    return view->rootContext();
}

void *silica_show(const char *qml)
{
    // The ambience's font for every text, as Silica's app sets it: Keel does not, and its
    // plain Text items (a slider's value) were in the system's font.
    if (QObject *theme = view->engine()->singletonInstance<QObject *>("Sailfish.Silica", "Theme")) {
        QFont font = QGuiApplication::font();
        font.setFamily(theme->property("fontFamily").toString());
        QGuiApplication::setFont(font);
    }
    view->setSource(QUrl::fromLocalFile(QString::fromUtf8(qml)));
    view->show();
    return view->rootObject();
}
