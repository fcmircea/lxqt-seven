/* BEGIN_COMMON_COPYRIGHT_HEADER
 * (c)LGPL2+
 *
 * LXQt - a lightweight, Qt based, desktop toolset
 * https://lxqt.org
 *
 * Copyright: 2012 Razor team
 * Authors:
 *   Petr Vanek <petr@scribus.info>
 *
 * This program or library is free software; you can redistribute it
 * and/or modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.

 * You should have received a copy of the GNU Lesser General
 * Public License along with this library; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA
 *
 * END_COMMON_COPYRIGHT_HEADER */

#include <QPainter>
#include <QUrl>
#include <QFile>
#include <QDateTime>
#include <QtDBus/QDBusArgument>
#include <QDebug>
#include <XdgIcon>
#include <KWindowSystem>
#include <KF6/KWindowSystem/KX11Extras>
#include <KF6/KWindowSystem/KWindowInfo>
#include <QEnterEvent>
#include <QMouseEvent>
#include <QPushButton>
#include <QStyle>
#include <QStyleOption>

#include "notification.h"
#include "notificationwidgets.h"

#define ICONSIZE QSize(32, 32)

// QLabel wraps only at spaces, so a word wider than the notification (a path, a
// command) is cut off. A zero-width space between the characters of a long word
// lets it wrap anywhere. Tags are copied as they are, and an entity counts as one character.
static QString breakLongWords(const QString &text)
{
    QString out;
    QStringList word;
    auto flush = [&] {
        out += word.join(word.size() > 20 ? QString(QChar(0x200B)) : QString());
        word.clear();
    };
    for (int i = 0; i < text.size(); ++i)
    {
        const QChar c = text.at(i);
        int end = c == QL1C('<') ? text.indexOf(QL1C('>'), i) : -1;
        if (end != -1 || c.isSpace())
        {
            flush();
            if (end == -1)
                end = i;
            out += text.mid(i, end - i + 1);
            i = end;
            continue;
        }
        end = c == QL1C('&') ? text.indexOf(QL1C(';'), i) : -1;
        if (end == -1 || end - i > 8)
            end = c.isHighSurrogate() && i + 1 < text.size() ? i + 1 : i;
        word << text.mid(i, end - i + 1);
        i = end;
    }
    flush();
    return out;
}


Notification::Notification(const QString &application,
                           const QString &summary, const QString &body,
                           const QString &icon, int timeout,
                           const QStringList& actions, const QVariantMap& hints,
                           QWidget *parent)
    : QWidget(parent),
      m_timer(nullptr),
      m_linkHovered(false),
      m_actionWidget(nullptr),
      m_icon(icon),
      m_timeout(timeout),
      m_actions(actions),
      m_hints(hints)
{
    setupUi(this);
    setObjectName(QSL("Notification"));
    setMouseTracking(true);

    setMaximumWidth(parent->width());
    setMinimumWidth(parent->width());
    setSizePolicy(QSizePolicy::Preferred, QSizePolicy::Fixed);

    setValues(application, summary, body, icon, timeout, actions, hints);

    connect(closeButton, &QPushButton::clicked, this, &Notification::closeButton_clicked);

    for (QLabel *label : {bodyLabel, summaryLabel})
    {
        connect(label, &QLabel::linkHovered, this, &Notification::linkHovered);

        label->installEventFilter(this);
    }
}

void Notification::setValues(const QString &application,
                             const QString &summary, const QString &body,
                             const QString &icon, int timeout,
                             const QStringList& actions, const QVariantMap& hints)
{
    // Basic properties *********************

    // Notifications spec set real order here:
    // An implementation which only displays one image or icon must
    // choose which one to display using the following order:
    //  - "image-data"
    //  - "image-path"
    //  - app_icon parameter
    //  - for compatibility reason, "icon_data", "image_data" and "image_path"

    if (!hints[QL1S("image-data")].isNull())
    {
        m_pixmap = getPixmapFromHint(hints[QL1S("image-data")]);
    }
    else if (!hints[QL1S("image_data")].isNull())
    {
        m_pixmap = getPixmapFromHint(hints[QL1S("image_data")]);
    }
    else if (!hints[QL1S("image-path")].isNull())
    {
        m_pixmap = getPixmapFromString(hints[QL1S("image-path")].toString());
    }
    else if (!hints[QL1S("image_path")].isNull())
    {
        m_pixmap = getPixmapFromString(hints[QL1S("image_path")].toString());
    }
    else if (!icon.isEmpty())
    {
        m_pixmap = getPixmapFromString(icon);
    }
    else if (!hints[QL1S("icon_data")].isNull())
    {
       m_pixmap = getPixmapFromHint(hints[QL1S("icon_data")]);
    }
    // issue #325: Do not display icon if it's not found...
    if (m_pixmap.isNull())
    {
        iconLabel->hide();
    }
    else
    {
        if (m_pixmap.size().width() > ICONSIZE.width()
            || m_pixmap.size().height() > ICONSIZE.height())
        {
            m_pixmap = m_pixmap.scaled(ICONSIZE, Qt::KeepAspectRatio, Qt::SmoothTransformation);
        }
        iconLabel->setPixmap(m_pixmap);
        iconLabel->show();
    }
    //XXX: workaround to properly set text labels widths (for correct sizeHints after setText)
    adjustSize();

    // application
    appLabel->setVisible(!application.isEmpty());
    appLabel->setFixedWidth(appLabel->width());
    appLabel->setText(application);

    // summary
    summaryLabel->setVisible(!summary.isEmpty() && application != summary);
    summaryLabel->setFixedWidth(summaryLabel->width());
    summaryLabel->setText(breakLongWords(summary));

    // body
    bodyLabel->setVisible(!body.isEmpty());
    bodyLabel->setFixedWidth(bodyLabel->width());
    //https://developer.gnome.org/notification-spec
    //Body - This is a multi-line body of text. Each line is a paragraph, server implementations are free to word wrap them as they see fit.
    //XXX: remove all unsupported tags?!? (supported <b>, <i>, <u>, <a>, <img>)
    QString formatted(body);
    bodyLabel->setText(breakLongWords(formatted.replace(QL1C('\n'), QStringLiteral("<br/>"))));

    // Timeout
    // Special values:
    //  < 0: server decides timeout
    //    0: infifite
    if (m_timer)
    {
        m_timer->stop();
        m_timer->deleteLater();
    }

    // -1 for server decides is handled in notifyd to save QSettings instance
    if (timeout > 0)
    {
        m_timer = new NotificationTimer(this);
        connect(m_timer, &NotificationTimer::timeout, this, &Notification::timeout);
        m_timer->start(timeout);
    }

    // Categories *********************
    if (!hints[QL1S("category")].isNull())
    {
        // TODO/FIXME: Categories - how to handle it?
    }

    // Urgency Levels *********************
    // Type    Description
    // 0   Low
    // 1   Normal
    // 2   Critical
    if (!hints[QL1S("urgency")].isNull())
    {
        // TODO/FIXME: Urgencies - how to handle it?
    }

    // Actions
    if (actions.count() && m_actionWidget == nullptr)
    {
        if (actions.count()/2 < 4)
            m_actionWidget = new NotificationActionsButtonsWidget(actions, this);
        else
            m_actionWidget = new NotificationActionsComboWidget(actions, this);

        connect(m_actionWidget, &NotificationActionsWidget::actionTriggered,
                this, &Notification::actionTriggered);

        actionsLayout->addWidget(m_actionWidget);
        m_actionWidget->show();
    }

    adjustSize();
    // ensure layout expansion
    setMinimumHeight(qMax(rect().height(), childrenRect().height()));
}

QString Notification::application() const
{
    return appLabel->text();
}

QString Notification::summary() const
{
    return summaryLabel->text().remove(QChar(0x200B));
}

QString Notification::body() const
{
    return bodyLabel->text().remove(QChar(0x200B));
}

bool Notification::hasActionButtons() const
{
    for (int i = 0; i < m_actions.count(); i += 2)
    {
        if (m_actions.at(i) != QL1S("default"))
            return true;
    }
    return false;
}

void Notification::stopTimer()
{
    if (m_timer)
        m_timer->stop();
}

void Notification::restartTimer()
{
    if (m_timer)
        m_timer->start(m_timeout);
}

void Notification::closeButton_clicked()
{
    if (m_timer)
        m_timer->stop();
    emit userCanceled();
}

void Notification::paintEvent(QPaintEvent *)
{
    QStyleOption opt;
    opt.initFrom(this);
    QPainter p(this);

#if (QT_VERSION >= QT_VERSION_CHECK(6,8,0))
    // NOTE: Starting from Qt 6.8.0, random artifacts are possible in
    // translucent windows under Wayland. This a workaround.
    if (QGuiApplication::platformName() == QStringLiteral("wayland")
        && testAttribute(Qt::WA_StyleSheetTarget))
    {
        auto origMode = p.compositionMode();
        p.setCompositionMode(QPainter::CompositionMode_Clear);
        p.fillRect(rect(), Qt::transparent);
        p.setCompositionMode(origMode);
    }
#endif

    style()->drawPrimitive(QStyle::PE_Widget, &opt, &p, this);
}

QPixmap Notification::getPixmapFromHint(const QVariant &argument) const
{
    int width, height, rowstride, bitsPerSample, channels;
    bool hasAlpha;
    QByteArray data;

    const QDBusArgument arg = argument.value<QDBusArgument>();
    arg.beginStructure();
    arg >> width;
    arg >> height;
    arg >> rowstride;
    arg >> hasAlpha;
    arg >> bitsPerSample;
    arg >> channels;
    arg >> data;
    arg.endStructure();

    bool rgb = !hasAlpha && channels == 3 && bitsPerSample == 8;
    QImage::Format imageFormat = rgb ? QImage::Format_RGB888 : QImage::Format_ARGB32;

    QImage img = QImage((uchar*)data.constData(), width, height, imageFormat);

    if (!rgb)
        img = img.rgbSwapped();

    return QPixmap::fromImage(img);
}

QPixmap Notification::getPixmapFromString(const QString &str) const
{
    QUrl url(str);
    if (url.isValid() && QFile::exists(url.toLocalFile()))
    {
//        qDebug() << "    getPixmapFromString by URL" << url;
        return QPixmap(url.toLocalFile());
    }
    else
    {
//        qDebug() << "    getPixmapFromString by XdgIcon theme" << str << ICONSIZE << XdgIcon::themeName();
//        qDebug() << "       " << XdgIcon::fromTheme(str) << "isnull:" << XdgIcon::fromTheme(str).isNull();
        // They say: do not display an icon if it;s not found - see #325
        return XdgIcon::fromTheme(str/*, XdgIcon::defaultApplicationIcon()*/).pixmap(ICONSIZE);
    }
}

void Notification::enterEvent(QEnterEvent * /*event*/)
{
    if (m_timer)
        m_timer->pause();
}

void Notification::leaveEvent(QEvent * /*event*/)
{
    if (m_timer)
        m_timer->resume();
}

bool Notification::eventFilter(QObject * /*obj*/, QEvent * event)
{
    // Catch mouseReleaseEvent on child labels if a link is not currently being hovered.
    //
    // This workarounds QTBUG-49025 where clicking on text does not propagate the mouseReleaseEvent
    // to the parent even though the text is not selectable and no link is being clicked.
    if (event->type() == QEvent::MouseButtonRelease && !m_linkHovered)
    {
        mouseReleaseEvent(static_cast<QMouseEvent*>(event));
        return true;
    }
    return false;
}

void Notification::linkHovered(const QString& link)
{
    m_linkHovered = !link.isEmpty();
}

void Notification::mouseReleaseEvent(QMouseEvent * event)
{
//    qDebug() << "CLICKED" << event;
    QString appName;
    QString windowTitle;

    if (m_actionWidget && m_actionWidget->hasDefaultAction())
    {
        emit actionTriggered(m_actionWidget->defaultAction());
        return;
    }

    const auto ids = KX11Extras::stackingOrder();
    for (const WId &i : ids)
    {
        KWindowInfo info = KWindowInfo(i, NET::WMName | NET::WMVisibleName);
        appName = info.name();
        windowTitle = info.visibleName();
        // qDebug() << "    " << i << "APPNAME" << appName << "TITLE" << windowTitle;
        if (appName.isEmpty())
        {
            QWidget::mouseReleaseEvent(event);
            return;
        }
        if (appName == appLabel->text() || windowTitle == appLabel->text())
        {
            if (auto w = QWidget::find(i))
                 w->raise();
            closeButton_clicked();
            return;
        }
    }
}

NotificationTimer::NotificationTimer(QObject *parent)
    : QTimer(parent),
      m_intervalMsec(-1)
{
}

void NotificationTimer::start(int msec)
{
    m_startTime = QDateTime::currentDateTime();
    m_intervalMsec = msec;
    QTimer::start(msec);
}

void NotificationTimer::pause()
{
    if (!isActive())
        return;

    stop();
}

void NotificationTimer::resume()
{
    if (isActive())
        return;

    m_intervalMsec -= m_startTime.msecsTo(QDateTime::currentDateTime());
    start(qMax(m_intervalMsec, 1000));
}
