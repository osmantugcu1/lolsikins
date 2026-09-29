#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFontDatabase>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QScreen>
#include <QSettings>

#include "CSLOLSkinRepo.h"
#include "CSLOLTools.h"
#include "CSLOLUtils.h"
#include "CSLOLVersion.h"

int main(int argc, char *argv[]) {
    CSLOLUtils::relaunchAdmin(argc, argv);

    qmlRegisterType<CSLOLTools>("customskinlol.tools", 1, 0, "CSLOLTools");
    qmlRegisterType<CSLOLSkinRepo>("customskinlol.tools", 1, 0, "CSLOLSkinRepo");
    qmlRegisterSingletonType(QUrl("qrc:/NeonTheme.qml"), "lolsikins.theme", 1, 0, "Neon");
    qmlRegisterSingletonType(QUrl("qrc:/I18n.qml"), "lolsikins.theme", 1, 0, "I18n");

#if QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#else
    if (QFileInfo info("opengl.txt"); info.exists()) {
        QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);
    }
#endif
    QGuiApplication app(argc, argv);
    app.setOrganizationName("LolSikins");
    app.setApplicationName("LolSikins");
    QDir::setCurrent(QCoreApplication::applicationDirPath());
    QSettings::setPath(QSettings::Format::IniFormat,
                       QSettings::Scope::SystemScope,
                       QCoreApplication::applicationDirPath());
    QSettings::setDefaultFormat(QSettings::Format::IniFormat);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("CSLOLUtils", new CSLOLUtils(&engine));
    engine.rootContext()->setContextProperty("CSLOL_VERSION", CSLOL::VERSION);
    engine.rootContext()->setContextProperty("CSLOL_COMMIT", CSLOL::COMMIT);
    engine.rootContext()->setContextProperty("CSLOL_DATE", CSLOL::DATE);
    const QUrl url(QStringLiteral("qrc:/main.qml"));
    QFile fontfile(":/fontawesome-webfont.ttf");
    fontfile.open(QFile::OpenModeFlag::ReadOnly);
    QFontDatabase::addApplicationFontFromData(fontfile.readAll());
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreated,
        &app,
        [url](QObject *obj, const QUrl &objUrl) {
            if (!obj && url == objUrl) QCoreApplication::exit(-1);
        },
        Qt::QueuedConnection);
    engine.load(url);

    // Keep the window inside the work area of its screen: a remembered or default size can be bigger than a
    // small or highly scaled screen, which pushed the title bar under the taskbar or off screen.
    if (!engine.rootObjects().isEmpty()) {
        if (auto window = qobject_cast<QWindow *>(engine.rootObjects().first()); window && window->screen()) {
            auto area = window->screen()->availableGeometry();
            auto frame = window->frameMargins();
            if (frame.isNull()) {
                frame = QMargins(8, 32, 8, 8);
            }
            auto fit = QSize(area.width() - frame.left() - frame.right(), area.height() - frame.top() - frame.bottom());
            window->setMinimumSize(window->minimumSize().boundedTo(fit));
            if (window->visibility() != QWindow::Maximized) {
                auto size = window->size().boundedTo(fit);
                window->resize(size);
                window->setPosition(area.x() + frame.left() + (fit.width() - size.width()) / 2,
                                    area.y() + frame.top() + (fit.height() - size.height()) / 2);
            }
        }
    }

    return app.exec();
}
