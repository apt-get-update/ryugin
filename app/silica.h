// Keel's SailfishApp for Go (silica.cpp, main_silica.go).
#ifndef SILICA_H
#define SILICA_H

#ifdef __cplusplus
extern "C" {
#endif

void silica_application(int *argc, char **argv);
void *silica_view(void);                 // the window's QQmlContext
void *silica_show(const char *qml);      // loads qml, shows it, returns the root QObject

#ifdef __cplusplus
}
#endif

#endif
