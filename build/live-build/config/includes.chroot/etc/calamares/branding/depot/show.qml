/* Depot OS — slideshow Calamares lúc đang cài (branding depot, logo "Depot by WrenEvil").
 * Giao diện Calamares là Qt (không theo theme GTK), nên tự tô nền tối cho hợp logo.
 * By WrenEvil.tech & nguyenquocanhz (nqatech)
 */
import QtQuick 2.0;
import calamares.slideshow 1.0;

Presentation
{
    id: presentation

    function onActivate() { }
    function onLeave() { }

    // nền tối phủ cả khung slideshow (không thì quanh slide còn viền trắng)
    Rectangle { anchors.fill: parent; color: "#07080c"; z: -1 }

    Timer {
        interval: 12000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Rectangle { anchors.fill: parent; color: "#07080c" }
        Image {
            id: logo1
            source: "depot-logo.png"
            width: 150; height: 150
            fillMode: Image.PreserveAspectFit
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top; anchors.topMargin: 40
        }
        Text {
            id: t1
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: logo1.bottom; anchors.topMargin: 22
            text: "Đang cài Depot OS"
            color: "#e8ecf5"; font.pixelSize: 26; font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: t1.bottom; anchors.topMargin: 12
            width: parent.width * 0.8
            text: "Vô tung vô ảnh — phần còn lại tự chạy, vài phút là xong.<br/>Đừng tắt máy hay rút USB cho tới khi có thông báo."
            color: "#8a90a2"; font.pixelSize: 15
            wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
        }
    }

    Slide {
        Rectangle { anchors.fill: parent; color: "#07080c" }
        Text {
            id: h2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top; anchors.topMargin: 70
            text: "App tải ngay trong lúc cài"
            color: "#e8ecf5"; font.pixelSize: 24; font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: h2.bottom; anchors.topMargin: 18
            width: parent.width * 0.8
            text: "Telegram, Claude, Discord, Antigravity, VLC, GParted, Phần mềm (Flathub), in ấn.<br/>"
                + "Không có mạng lúc này cũng không sao: máy tự cài khi có mạng."
            color: "#8a90a2"; font.pixelSize: 15
            wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
        }
    }

    Slide {
        Rectangle { anchors.fill: parent; color: "#07080c" }
        Text {
            id: h3
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top; anchors.topMargin: 70
            text: "Có sẵn sau khi cài"
            color: "#e8ecf5"; font.pixelSize: 24; font.bold: true
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: h3.bottom; anchors.topMargin: 18
            width: parent.width * 0.8
            text: "Bố cục desktop kiểu macOS, Windows 10 hoặc Windows 11 · Hiệu ứng hình ảnh · Gõ tiếng Việt Unikey (Ctrl+Space)<br/>"
                + "Cảm biến phần cứng · Chẩn đoán main · Cập nhật kiểu Windows, không tự khởi động lại."
            color: "#8a90a2"; font.pixelSize: 15
            wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: 24
            text: "Depot by Wren<font color=\"#ff2d3d\">Evil</font> · WrenEvil.tech &amp; nguyenquocanhz (nqatech)"
            textFormat: Text.RichText
            color: "#5d6272"; font.pixelSize: 12
        }
    }
}
