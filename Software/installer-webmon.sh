#!/bin/bash

: <<'DISCLAIMER'

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

This script is licensed under the terms of the MIT license.

DISCLAIMER

CONFIG=/boot/config.txt
TIMESYNC=/etc/systemd/timesyncd.conf

confirm() {
    read -r -p "$1 [j/N] " response < /dev/tty
    if [[ $response =~ ^(ja|j|J)$ ]]; then
        true
    else
        false
    fi
}

add_dtoverlay() {
    if grep -q "^dtoverlay=$1" $CONFIG; then
        echo -e "\n$1 overlay bereits aktiv"
    elif grep -q "^#dtoverlay=$1" $CONFIG; then
        sudo sed -i "/^#dtoverlay=$1$/ s|#||" $CONFIG
        echo -e "\nOverlay $1 zu $CONFIG hinzugefügt"
    else
        echo "dtoverlay=$1" | sudo tee -a $CONFIG &> /dev/null
        echo -e "\nOverlay $1 zu $CONFIG hinzugefügt"
    fi
}

add_timesync() {
    if grep -q "^NTP=$1" $TIMESYNC; then
        echo -e "\n$1 bereits als Zeitserver gesetzt"
    elif grep -q "^#NTP=" $TIMESYNC; then
        sudo sed -i "/^#NTP=/ s|#NTP=|NTP=$1|" $TIMESYNC
        echo -e "\n$1 als Zeitserver gesetzt"
    else
        sudo sed -i "/^NTP=/ a NTP=$1" $TIMESYNC
        echo -e "\n$1 als Zeitserver hinzugefügt"
    fi
}

echo ""
echo "Dieses Script installiert die PiLogger WebMonitor Software."
echo ""

if confirm "Wollen Sie fortfahren ?"; then
    echo ""
    echo "Wenn Ihr Heimnetz-Router einen NTP-Zeitserver zur Verfügung stellt,"
    echo "können Sie die Zeit des Raspberry Pi damit synchronisieren."
    echo "Dadurch wird kein externer Internetzugang mehr benötigt."
    echo ""
    if confirm "Heimnetz-Router als Zeitserver verwenden ?"; then
        INFO=$(route -n | grep -Po "0\.0\.0\.0\s*\K\S+(?=\s*0\.0\.0\.0)")
        add_timesync $INFO
        echo ""
    fi
    add_dtoverlay i2c-bcm2708
    echo ""
    sudo apt-get update
    echo ""
    sudo apt-get -y install python3-smbus
    echo ""
    sudo apt-get -y install python3-rpi.gpio
    echo ""
    sudo apt-get -y install python3-bottle
    echo ""
    echo "Download Archiv..."
    echo ""
    curl -L https://www.pilogger.de/get/pilo-webmon -o PiLo-WebMon.zip
    if [ $? == 1 ]; then
        echo ""
        echo "Datei konnte nicht heruntergeladen werden."
        echo ""
    else
        echo ""
        unzip -o PiLo-WebMon.zip
        rm PiLo-WebMon.zip
        echo ""
        sudo cp /home/pi/pilo-webmon.service /lib/systemd/system/pilo-webmon.service
        sudo systemctl daemon-reload
        sudo systemctl enable pilo-webmon.service
        if [ $? == 1 ]; then
            echo "Fehler beim Einrichten Autostart"
        else
            echo "Autostart eingerichtet"
        fi
        echo ""
        echo "Die täglichen Kontakte zum Raspbian-Update-Server (apt-daily)"
        echo "sind externe Internetkontakte und können deaktiviert werden."
        echo ""
        if confirm "Möchten Sie Apt-daily deaktivieren ?"; then
            sudo systemctl stop apt-daily.timer
            sudo systemctl disable apt-daily.timer
            systemctl status apt-daily.timer --no-pager
            sudo systemctl mask apt-daily.service
            sudo systemctl daemon-reload
            systemctl status apt-daily.service --no-pager
            sudo systemctl stop apt-daily-upgrade.timer
            sudo systemctl disable apt-daily-upgrade.timer
            systemctl status apt-daily-upgrade.timer --no-pager
        fi
        echo ""
        echo "Die Installation ist jetzt durchgeführt."
        echo "Einige Änderungen am System erfordern einen Neustart."
        echo "Nach dem Neustart wird automatisch PiLogger WebMon ausgeführt."
        echo ""
        if confirm "Bereit zum Neustart ?"; then
            sync && sudo reboot
        fi
    fi
fi

exit 0
