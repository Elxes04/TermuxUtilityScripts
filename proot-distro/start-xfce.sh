#!/data/data/com.termux/files/usr/bin/bash

# Funzione per loggare messaggi
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Riavvio il servizio dbus..."
dbus-daemon --session --address=unix:path=$PREFIX/var/run/dbus/system_bus_socket --fork
if [[ $? -eq 0 ]]; then
    log "Servizio dbus riavviato con successo."
else
    log "Errore nel riavvio del servizio dbus."
    exit 1
fi

log "Avvio PulseAudio con supporto TCP..."
pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1
if [[ $? -ne 0 ]]; then
    log "Errore nell'avvio di PulseAudio."
    exit 1
fi

log "Preparo la sessione Termux-X11..."

# Avvio della sessione X11
export XDG_RUNTIME_DIR=${TMPDIR}
termux-x11 :0 >/dev/null 2>&1 &
sleep 5  # Aumentato il tempo per garantire l'inizializzazione completa

log "Avvio l'attività principale di Termux-X11..."
if am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1; then
    log "Termux-X11 avviato con successo."
else
    log "Errore nell'avvio di Termux-X11."
    exit 1
fi
sleep 3  # Aggiunto un ulteriore ritardo per la stabilizzazione

log "Avvio Ubuntu con Proot e XFCE..."
proot-distro login ubuntu --shared-tmp -- /bin/bash -c '
    export DISPLAY=:0
    export PULSE_SERVER=127.0.0.1
    export XDG_RUNTIME_DIR=${TMPDIR}

    echo "[ $(date +%Y-%m-%d\ %H:%M:%S) ] Chiudo eventuali processi X11 aperti..."
    
    # Fermare i processi X11 già esistenti, se presenti
    if pgrep -x "Xorg" >/dev/null || pgrep -x "termux-x11" >/dev/null; then
        echo "[ $(date +%Y-%m-%d\ %H:%M:%S) ] Server X già in esecuzione, fermo i processi..."
        pkill -f "Xorg" 2>/dev/null
        pkill -f "termux-x11" 2>/dev/null
        sleep 2
        echo "[ $(date +%Y-%m-%d\ %H:%M:%S) ] Processi X11 terminati."
    else
        echo "[ $(date +%Y-%m-%d\ %H:%M:%S) ] Nessun server X attivo, procedo."
    fi

    # Rimuovere eventuali file di blocco
    echo "[ $(date +%Y-%m-%d\ %H:%M:%S) ] Rimuovo eventuali file di blocco..."
    rm -f /tmp/.X0-lock /tmp/.X11-unix/X0

    # Avvio del server dbus e XFCE
    service dbus start
    su main -c "DISPLAY=:0 startxfce4"
'
if [[ $? -eq 0 ]]; then
    log "Sessione Ubuntu con XFCE avviata correttamente."
else
    log "Errore nell'avvio della sessione Ubuntu."
    exit 1
fi

log "Script completato con successo."
exit 0
