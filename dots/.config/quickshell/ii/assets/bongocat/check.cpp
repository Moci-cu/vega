// g++ check.cpp -o /tmp/bongocat-svg-check $(pkg-config --cflags --libs Qt6Svg Qt6Gui)
// QT_QPA_PLATFORM=offscreen /tmp/bongocat-svg-check *.svg
#include <QGuiApplication>
#include <QSvgRenderer>
#include <QImage>
#include <QPainter>
#include <QFile>
#include <cassert>
#include <cstdio>

int main(int argc, char **argv) {
    QGuiApplication app(argc, argv);
    assert(argc == 5);
    for (int i = 1; i < argc; ++i) {
        QFile file(argv[i]);
        assert(file.open(QIODevice::ReadOnly));
        const auto svg = file.readAll();
        assert(!svg.contains("<image") && !svg.contains("rgba("));
        QSvgRenderer renderer(svg);
        assert(renderer.isValid());
        assert(renderer.viewBoxF() == QRectF(70, 135, 365, 220));
        QImage image(365, 220, QImage::Format_ARGB32_Premultiplied);
        image.fill(Qt::transparent);
        QPainter painter(&image);
        renderer.render(&painter);
        painter.end();
        for (int x = 0; x < image.width(); ++x) {
            assert(image.pixelColor(x, 0).alpha() == 0);
            assert(image.pixelColor(x, image.height() - 1).alpha() == 0);
        }
        for (int y = 0; y < image.height(); ++y) {
            assert(image.pixelColor(0, y).alpha() == 0);
            assert(image.pixelColor(image.width() - 1, y).alpha() == 0);
        }
        assert(image.pixelColor(180, 90).alpha() > 0);
    }
    puts("PASS: four Qt SVG frames, transparent borders, common bounds, no reference PNGs");
}
