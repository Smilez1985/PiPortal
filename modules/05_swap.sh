#!/usr/bin/env bash
# =============================================================================
#  PiPortal – Modul 05: Swap & zram
#  - SD-Swapfile dynamisch nach SD-Kartengröße (Staffel 2/4/8/16 GB), gedeckelt
#    durch den tatsächlich freien Platz. Bevorzugt DietPis eigenes Werkzeug.
#  - zram (komprimierter RAM-Swap) sicherstellen – RAM-begrenzt, KEINE 16 GB!
#  - vm.swappiness setzen (zram/ RAM bevorzugen, SD-Karte schonen).
#
#  Begriffsklärung:
#    * SD-Swapfile = liegt auf der Karte, kann groß sein (8/16 GB). <- Staffel
#    * zram        = komprimierter Swap IM RAM, max ~RAM-Größe (hier ~350 MB).
#    * RAM-Disk    = tmpfs für /tmp und /var/log (DietPi RAMlog), unverändert.
# =============================================================================

module_05_swap() {
    log_step "Phase 0.5 – Swap & zram"

    # ------------------------------------------------- 1. SD-Kartengröße -----
    local root_src card_dev card_bytes card_gb
    root_src="$(findmnt -no SOURCE / 2>/dev/null)"                  # z. B. /dev/mmcblk0p2
    card_dev="/dev/$(lsblk -no PKNAME "$root_src" 2>/dev/null | head -n1)"  # -> /dev/mmcblk0
    if [ -b "$card_dev" ]; then
        card_bytes="$(blockdev --getsize64 "$card_dev" 2>/dev/null || echo 0)"
    else
        card_bytes=0
    fi
    card_gb=$(( card_bytes / 1000000000 ))     # dezimale GB (wie Hersteller angeben)
    log_info "SD-Karte: ${card_dev} (~${card_gb} GB)"

    # ------------------------------------------------- 2. Zielgröße (MiB) ----
    local target_mib
    case "${SWAP_MODE:-auto}" in
        auto|AUTO|"")
            if   [ "$card_gb" -ge 64 ]; then target_mib=16384   # 16 GB
            elif [ "$card_gb" -ge 32 ]; then target_mib=8192    #  8 GB
            elif [ "$card_gb" -ge 16 ]; then target_mib=4096    #  4 GB
            else                             target_mib=2048    #  2 GB
            fi
            ;;
        0)      target_mib=0 ;;                                  # Swap deaktivieren
        *)      target_mib="${SWAP_MODE}" ;;                     # feste MiB-Zahl
    esac

    # ------------------------------------ 3. Deckeln durch freien Platz ------
    local loc="${SWAP_LOCATION:-/var/swap}"
    local reserve_mib="${SWAP_RESERVE_MIB:-8192}"               # so viel frei lassen
    local avail_mib cur_mib effective_free
    avail_mib=$(( $(df -B1M --output=avail / | tail -1 | tr -d ' ') ))
    cur_mib=0
    [ -f "$loc" ] && cur_mib=$(( $(stat -c%s "$loc") / 1048576 ))
    # Beim Ersetzen wird der alte Swapfile frei => zum verfügbaren Platz addieren.
    effective_free=$(( avail_mib + cur_mib ))

    if [ "$target_mib" -gt 0 ]; then
        local max_allow=$(( effective_free - reserve_mib ))
        if [ "$max_allow" -lt 512 ]; then
            log_warn "Zu wenig freier Platz für Swap (frei ~${avail_mib} MiB). Swap unverändert gelassen."
            target_mib="$cur_mib"
        elif [ "$target_mib" -gt "$max_allow" ]; then
            log_warn "Zielgröße ${target_mib} MiB überschreitet freien Platz – reduziere auf ${max_allow} MiB."
            target_mib="$max_allow"
        fi
    fi

    # ------------------------------------ 4. Swapfile idempotent setzen ------
    # Nur neu bauen, wenn die Abweichung > 256 MiB ist (spart SD-Schreibzyklen).
    local diff=$(( target_mib - cur_mib )); [ "$diff" -lt 0 ] && diff=$(( -diff ))
    if [ "$diff" -le 256 ] && [ "$cur_mib" -gt 0 ] && [ "$target_mib" -gt 0 ]; then
        log_skip "SD-Swapfile bereits ~${cur_mib} MiB (Ziel ${target_mib} MiB) – unverändert."
    else
        set_swapfile "$target_mib" "$loc"
    fi

    # ------------------------------------------------- 5. zram sicherstellen -
    if [ "${ENABLE_ZRAM:-1}" = "1" ]; then
        ensure_zram
    else
        log_skip "zram deaktiviert (ENABLE_ZRAM=0)."
    fi

    # ------------------------------------------------- 6. swappiness ---------
    local sw="${SWAPPINESS:-80}"
    write_file_if_changed /etc/sysctl.d/99-piportal-swap.conf 0644 <<EOF
# Von PiPortal verwaltet. Höher = eher auslagern (zram ist schnell + schont RAM).
vm.swappiness=${sw}
vm.vfs_cache_pressure=50
EOF
    sysctl -p /etc/sysctl.d/99-piportal-swap.conf >/dev/null 2>&1 || true
    log_ok "vm.swappiness=${sw} gesetzt."

    log_info "Aktueller Swap-Status:"
    swapon --show 2>/dev/null | sed 's/^/    /' || true
}

# Legt den SD-Swapfile auf die gewünschte Größe (MiB). DietPi-Tool bevorzugt.
set_swapfile() {
    local mib="$1" loc="$2"
    local dietpi_tool="/boot/dietpi/func/dietpi-set_swapfile"

    if [ "$mib" -eq 0 ]; then
        log_info "Deaktiviere SD-Swapfile."
        swapoff "$loc" 2>/dev/null || true
        rm -f "$loc"
        sed -i "\|^$loc |d" /etc/fstab 2>/dev/null || true
        return 0
    fi

    log_info "Setze SD-Swapfile auf ${mib} MiB (${loc}) …"
    if [ -x "$dietpi_tool" ]; then
        # DietPi-konform: pflegt fstab + dietpi.txt selbst.
        "$dietpi_tool" "$mib" "$loc" && { log_ok "Swapfile via DietPi gesetzt (${mib} MiB)."; return 0; }
        log_warn "dietpi-set_swapfile fehlgeschlagen – nutze klassischen Weg."
    fi

    # Klassischer Fallback (nicht-DietPi).
    swapoff "$loc" 2>/dev/null || true
    rm -f "$loc"
    if ! fallocate -l "${mib}M" "$loc" 2>/dev/null; then
        dd if=/dev/zero of="$loc" bs=1M count="$mib" status=none
    fi
    chmod 600 "$loc"
    mkswap "$loc" >/dev/null
    swapon "$loc"
    ensure_line /etc/fstab "$loc none swap sw 0 0"
    log_ok "Swapfile klassisch gesetzt (${mib} MiB)."
}

# Stellt zram als komprimierten RAM-Swap sicher (RAM-relativ, nicht SD).
ensure_zram() {
    if systemctl list-unit-files 2>/dev/null | grep -q '^zramswap.service'; then
        log_skip "zram-Dienst (zramswap.service) bereits vorhanden."
    else
        log_info "Installiere zram-tools …"
        ensure_pkg zram-tools
    fi
    # Konfiguration: 75 % des RAM als zram (wird komprimiert, effektiv mehr).
    if [ -f /etc/default/zramswap ]; then
        write_file_if_changed /etc/default/zramswap 0644 <<EOF
# Von PiPortal verwaltet.
ALGO=lz4
PERCENT=${ZRAM_PERCENT:-75}
PRIORITY=100
EOF
        systemctl restart zramswap.service 2>/dev/null && log_ok "zram aktiv (${ZRAM_PERCENT:-75} % RAM, lz4)." || log_warn "zramswap.service-Neustart fehlgeschlagen."
    else
        # DietPi-eigener zram-Weg (falls zram-tools nicht genutzt wird).
        systemctl enable --now zramswap.service 2>/dev/null \
            && log_ok "zram-Dienst aktiviert." \
            || log_info "Kein zramswap.service – zram ggf. über DietPi (dietpi-config) verwaltet."
    fi
}
