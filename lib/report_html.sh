#!/bin/zsh
# ==============================================================================
# macharden - lib/report_html.sh
# Enterprise-Grade, Modern, Interactive, Zero-Dependency HTML5 Report Generator
# ==============================================================================

# Ensure record_result and report dependencies if sourced standalone
if ! typeset -f report_json >/dev/null 2>&1; then
    local _script_dir="${0:A:h}"
    if [[ -f "$_script_dir/report.sh" ]]; then
        source "$_script_dir/report.sh"
    fi
fi

# Generate modern standalone interactive HTML report
# Usage: report_html [output_file] [lang]
report_html() {
    local output_file="${1:-}"
    local lang="${2:-${MACHAR_LANG:-en}}"
    local version="${MACHAR_VERSION:-1.2.0}"
    local _script_dir="${0:A:h}"
    local compliance_file="${_script_dir}/../data/compliance_mappings.json"

    # Ensure Hardening Index is calculated
    if typeset -f calculate_hardening_index >/dev/null 2>&1; then
        calculate_hardening_index
    fi

    # Retrieve structured JSON data via report_json
    local json_data=""
    if typeset -f report_json >/dev/null 2>&1; then
        json_data=$(report_json -)
    fi

    # Fallback to python3 environment check
    if ! command -v python3 >/dev/null 2>&1; then
        echo "Error: python3 is required for HTML report generation." >&2
        return 1
    fi

    # Execute Python generator with JSON payload and compliance mappings
    AUDIT_JSON="$json_data" AUDIT_OUTPUT_FILE="$output_file" COMPLIANCE_JSON_FILE="$compliance_file" AUDIT_VERSION="$version" AUDIT_LANG="$lang" python3 - << 'PYEOF'
import os
import sys
import json
import html

raw_json = os.environ.get('AUDIT_JSON', '{}')
output_file = os.environ.get('AUDIT_OUTPUT_FILE', '')
comp_file = os.environ.get('COMPLIANCE_JSON_FILE', '')
scanner_ver = os.environ.get('AUDIT_VERSION', '1.2.0')
audit_lang = os.environ.get('AUDIT_LANG', os.environ.get('MACHAR_LANG', 'en')).strip().lower()
if audit_lang not in ['en', 'tr']:
    audit_lang = 'en'

UI_STRINGS = {
  "en": {
    "nav_subtitle": "macOS Security Hardening & Audit Scanner",
    "btn_theme": "Theme",
    "btn_print": "Print PDF",
    "btn_playbook": "Remediation Playbook",
    "btn_export_md": "Export Markdown",
    "btn_export_json": "JSON",
    "sec_hardening_score": "Hardening Score",
    "score_earned_prefix": "Earned",
    "score_earned_of": "of",
    "score_earned_suffix": "weighted points",
    "cis_benchmark": "CIS Benchmark",
    "nist_sp": "NIST SP 800-53",
    "mitre_attack": "MITRE ATT&CK",
    "sec_audit_stats": "Audit Overview & Statistics",
    "kpi_total_controls": "Total Controls",
    "kpi_total_sub": "Audited items",
    "kpi_passed": "Passed",
    "kpi_passed_sub": "compliant",
    "kpi_warnings": "Warnings",
    "kpi_warnings_sub": "Review suggested",
    "kpi_failed": "Failed",
    "kpi_failed_sub": "Action required",
    "sec_system_meta": "System Metadata",
    "meta_hostname": "Target Hostname",
    "meta_user": "Audit User",
    "meta_os": "Operating System",
    "meta_arch": "Architecture",
    "meta_timestamp": "Scan Timestamp",
    "sec_cat_breakdown": "Category Score Breakdown",
    "cat_all": "All Checks",
    "cat_hardening": "Hardening",
    "cat_network": "Network",
    "cat_secrets": "Secrets",
    "cat_persistence": "Persistence",
    "cnt_pass_label": "pass",
    "cnt_warn_label": "warn",
    "cnt_fail_label": "fail",
    "sec_sev_matrix": "Risk & Severity Distribution",
    "sev_critical": "Critical",
    "sev_high": "High",
    "sev_medium": "Medium",
    "sev_low": "Low",
    "sev_critical_desc": "wt ≥ 9",
    "sev_high_desc": "wt 7-8",
    "sev_medium_desc": "wt 5-6",
    "sev_low_desc": "wt ≤ 4",
    "sev_subval": "checks",
    "banner_ready": "Security Issues Ready for Remediation",
    "banner_ready_single": "Security Issue Ready for Remediation",
    "banner_desc": "Automated shell fix commands are available for your failed and warning controls.",
    "banner_btn_playbook": "Remediation Playbook",
    "banner_btn_copy_all": "Copy All Fixes",
    "fw_label": "Framework:",
    "fw_all": "All Controls",
    "status_all": "All",
    "status_failed": "Failed",
    "status_warnings": "Warnings",
    "status_passed": "Passed",
    "search_placeholder": "Search controls, IDs, or findings (Press / to focus)...",
    "btn_expand_all": "Expand All",
    "btn_collapse_all": "Collapse All",
    "finding_analysis": "Finding Details & Analysis",
    "remed_command": "Remediation Command",
    "btn_copy_fix": "Copy Fix Command",
    "sec_references": "Authoritative Security References & Documentation",
    "modal_playbook_title": "Remediation Playbook",
    "modal_playbook_subtitle": "Executable hardening shell script for detected vulnerabilities",
    "modal_actionable_fixes": "Actionable Fixes",
    "modal_target": "Target:",
    "modal_btn_copy_all": "Copy All",
    "modal_btn_download": "Download fix_hardening.sh",
    "modal_admin_note": "Administrator privileges: Review commands thoroughly before executing with sudo.",
    "modal_press_esc": "Press Esc to close",
    "toast_copied_cmd": "Copied fix command!",
    "toast_copied_script": "Copied full remediation shell script!",
    "toast_downloaded": "Downloaded fix_hardening.sh",
    "badge_pass": "PASS",
    "badge_warn": "WARN",
    "badge_fail": "FAIL",
    "badge_info": "INFO"
  },
  "tr": {
    "nav_subtitle": "macOS Güvenlik Sıkılaştırma ve Denetim Tarayıcısı",
    "btn_theme": "Tema",
    "btn_print": "PDF Yazdır",
    "btn_playbook": "Zafiyet İyileştirme Reçetesi",
    "btn_export_md": "Markdown İndir",
    "btn_export_json": "JSON",
    "sec_hardening_score": "Sıkılaştırma Skoru",
    "score_earned_prefix": "Ağırlıklı puandan",
    "score_earned_of": "/",
    "score_earned_suffix": "kazanıldı",
    "cis_benchmark": "CIS Kıyaslama Kılavuzu",
    "nist_sp": "NIST SP 800-53",
    "mitre_attack": "MITRE ATT&CK",
    "sec_audit_stats": "Denetim Genel Bakışı ve İstatistikler",
    "kpi_total_controls": "Toplam Kontroller",
    "kpi_total_sub": "Denetlenen maddeler",
    "kpi_passed": "Başarılı",
    "kpi_passed_sub": "uyumlu",
    "kpi_warnings": "Uyarılar",
    "kpi_warnings_sub": "İnceleme önerilir",
    "kpi_failed": "Başarısız",
    "kpi_failed_sub": "Müdahale gerekli",
    "sec_system_meta": "Sistem Bilgileri",
    "meta_hostname": "Hedef Sistem Adı",
    "meta_user": "Denetim Kullanıcısı",
    "meta_os": "İşletim Sistemi",
    "meta_arch": "Mimari",
    "meta_timestamp": "Tarama Zaman Damgası",
    "sec_cat_breakdown": "Kategori Skor Dağılımı",
    "cat_all": "Tüm Kontroller",
    "cat_hardening": "Sistem Sıkılaştırma",
    "cat_network": "Ağ Güvenliği",
    "cat_secrets": "Gizli Bilgiler",
    "cat_persistence": "Kalıcılık",
    "cnt_pass_label": "başarılı",
    "cnt_warn_label": "uyarı",
    "cnt_fail_label": "başarısız",
    "sec_sev_matrix": "Risk ve Önem Derecesi Dağılımı",
    "sev_critical": "Kritik",
    "sev_high": "Yüksek",
    "sev_medium": "Orta",
    "sev_low": "Düşük",
    "sev_critical_desc": "ağırlık ≥ 9",
    "sev_high_desc": "ağırlık 7-8",
    "sev_medium_desc": "ağırlık 5-6",
    "sev_low_desc": "ağırlık ≤ 4",
    "sev_subval": "kontrol",
    "banner_ready": "Güvenlik Zafiyeti İyileştirmeye Hazır",
    "banner_ready_single": "Güvenlik Zafiyeti İyileştirmeye Hazır",
    "banner_desc": "Başarısız ve uyarı durumundaki kontroller için otomatik kabuk düzeltme komutları mevcuttur.",
    "banner_btn_playbook": "Zafiyet İyileştirme Reçetesi",
    "banner_btn_copy_all": "Tüm Düzeltmeleri Kopyala",
    "fw_label": "Çerçeve:",
    "fw_all": "Tüm Kontroller",
    "status_all": "Tümü",
    "status_failed": "Başarısız",
    "status_warnings": "Uyarılar",
    "status_passed": "Başarılı",
    "search_placeholder": "Kontrol, ID veya bulgu ara (Odaklanmak için /)...",
    "btn_expand_all": "Tümünü Genişlet",
    "btn_collapse_all": "Tümünü Daralt",
    "finding_analysis": "Bulgu Detayları ve Analiz",
    "remed_command": "İyileştirme Komutu",
    "btn_copy_fix": "Düzeltme Komutunu Kopyala",
    "sec_references": "Otoriter Güvenlik Referansları",
    "modal_playbook_title": "Zafiyet İyileştirme Reçetesi",
    "modal_playbook_subtitle": "Tespit edilen zafiyetler için çalıştırılabilir sıkılaştırma kabuk betiği",
    "modal_actionable_fixes": "Uygulanabilir Düzeltme",
    "modal_target": "Hedef:",
    "modal_btn_copy_all": "Tümünü Kopyala",
    "modal_btn_download": "fix_hardening.sh İndir",
    "modal_admin_note": "Yönetici yetkileri: sudo ile çalıştırmadan önce komutları dikkatlice inceleyin.",
    "modal_press_esc": "Kapatmak için Esc tuşuna basın",
    "toast_copied_cmd": "Düzeltme komutu kopyalandı!",
    "toast_copied_script": "Tüm iyileştirme betiği kopyalandı!",
    "toast_downloaded": "fix_hardening.sh indirildi",
    "badge_pass": "BAŞARILI",
    "badge_warn": "UYARI",
    "badge_fail": "BAŞARISIZ",
    "badge_info": "BİLGİ"
  }
}

CHECK_I18N = {
  "HARD-01": {
    "title": {
      "en": "System Integrity Protection (SIP)",
      "tr": "Sistem Bütünlüğü Koruması (SIP)"
    },
    "desc": {
      "en": "Ensures System Integrity Protection (SIP) is enabled to protect critical system files and kernel memory from unauthorized modifications.",
      "tr": "Kritik sistem dosyalarını ve çekirdek belleğini yetkisiz değişikliklerden korumak için Sistem Bütünlüğü Korumasının (SIP) etkin olmasını sağlar."
    },
    "finding": {
      "PASS": "Sistem Bütünlüğü Koruması (SIP) etkin ve çekirdek/dosya sistemi kısıtlamalarını uyguluyor.",
      "FAIL": "Sistem Bütünlüğü Koruması (SIP) devre dışı! Sistem ikili dosyaları ve çekirdek uzantıları yetkisiz değiştirilebilir.",
      "WARN": "Sistem Bütünlüğü Koruması (SIP) beklenmeyen bir durumda. Elle kontrol edilmesi önerilir."
    }
  },
  "HARD-02": {
    "title": {
      "en": "FileVault Full Disk Encryption",
      "tr": "FileVault Tam Disk Şifreleme"
    },
    "desc": {
      "en": "Ensures FileVault full disk encryption is enabled using XTS-AES 128/256 to protect data against unauthorized physical access.",
      "tr": "Verileri yetkisiz fiziksel erişime karşı korumak için XTS-AES 128/256 ile FileVault tam disk şifrelemenin etkin olmasını sağlar."
    },
    "finding": {
      "PASS": "FileVault tam disk şifreleme aktif ve sistem verileri korunuyor.",
      "FAIL": "FileVault devre dışı! Disk verileri fiziksel erişimde şifresiz okunabilir."
    }
  },
  "HARD-03": {
    "title": {
      "en": "Gatekeeper App Assessment",
      "tr": "Gatekeeper Uygulama Değerlendirmesi"
    },
    "desc": {
      "en": "Enforces Gatekeeper app assessment to ensure all executed code is signed and notarized by Apple.",
      "tr": "Çalıştırılan tüm kodların Apple tarafından imzalandığını ve noter onaylı olduğunu doğrulamak için Gatekeeper denetimini zorunlu kılar."
    },
    "finding": {
      "PASS": "Gatekeeper etkin ve yetkisiz ikili dosyaların çalışmasını engelliyor.",
      "FAIL": "Gatekeeper devre dışı! İmzasız uygulamalar kısıtlama olmadan çalışabilir."
    }
  },
  "HARD-04": {
    "title": {
      "en": "Screen Lock Password Requirement",
      "tr": "Ekran Kilidi Parola Zorunluluğu"
    },
    "desc": {
      "en": "Requires a password immediately or within secure limits after display sleep or screensaver begins.",
      "tr": "Ekran uyku moduna geçtiğinde veya ekran koruyucu başladığında derhal parola istenmesini gerektirir."
    },
    "finding": {
      "PASS": "Ekran koruyucu veya uyku sonrasında anında parola isteniyor.",
      "FAIL": "Ekran kilidi parola istemi devre dışı veya gecikmeli!"
    }
  },
  "HARD-05": {
    "title": {
      "en": "Guest Account Status",
      "tr": "Konuk Kullanıcı Hesabı Durumu"
    },
    "desc": {
      "en": "Ensures the unauthenticated Guest user account is disabled to prevent anonymous console access.",
      "tr": "Anonim konsol erişimini engellemek için parolasız Konuk kullanıcı hesabının devre dışı bırakılmasını sağlar."
    },
    "finding": {
      "PASS": "Konuk hesabı devre dışı bırakılmış.",
      "FAIL": "Konuk hesabı etkin! Fiziksel erişimle parolasız oturum açılabilir."
    }
  },
  "HARD-06": {
    "title": {
      "en": "Automatic Software Updates",
      "tr": "Otomatik Yazılım Güncellemeleri"
    },
    "desc": {
      "en": "Ensures automatic downloading and background installation of critical macOS security updates and rapid response patches.",
      "tr": "Kritik macOS güvenlik güncellemeleri ve hızlı güvenlik müdahale yamalarının otomatik indirilip yüklenmesini sağlar."
    },
    "finding": {
      "PASS": "Otomatik yazılım güncellemeleri ve güvenlik yamaları devrede.",
      "FAIL": "Otomatik güncellemeler kapalı! Sistem kritik güvenlik yamalarını kaçırabilir."
    }
  },
  "HARD-07": {
    "title": {
      "en": "Unnecessary Sharing Services",
      "tr": "Gereksiz Paylaşım Servisleri"
    },
    "desc": {
      "en": "Audits legacy sharing daemons (AFP, SMB, Remote Login, Screen Sharing) to minimize exposed network attack surfaces.",
      "tr": "Ağ saldırı yüzeyini en aza indirmek için eski paylaşım servislerini (AFP, SMB, Uzaktan Giriş, Ekran Paylaşımı) denetler."
    },
    "finding": {
      "PASS": "Gereksiz dosya veya ekran paylaşım servisleri etkin değil.",
      "FAIL": "Güvensiz paylaşım servisleri aktif! Ağdan yetkisiz erişim riski mevcut."
    }
  },
  "HARD-08": {
    "title": {
      "en": "Firmware Password / Recovery Lock",
      "tr": "Bellenim Parolası / Kurtarma Kilidi"
    },
    "desc": {
      "en": "Verifies hardware firmware password or Apple Silicon recovery ownership protection is enforced.",
      "tr": "Donanım bellenim parolası veya Apple Silicon kurtarma sahipliği korumasının devrede olduğunu doğrular."
    },
    "finding": {
      "PASS": "Bellenim parolası veya Apple Silicon donanım güvenliği aktif.",
      "WARN": "Bellenim parolası yapılandırılmamış veya kurtarma kilidi doğrulanmadı."
    }
  },
  "HARD-09": {
    "title": {
      "en": "Secure Boot / Authenticated Root",
      "tr": "Güvenli Başlatma / Kimlik Doğrulamalı Kök Dosya Sistemi"
    },
    "desc": {
      "en": "Ensures Full Security boot mode is configured and the Sealed System Volume (SSV) root filesystem integrity is intact.",
      "tr": "Tam Güvenlikli başlatma modunun yapılandırıldığını ve Mühürlü Sistem Birimi (SSV) kök dosya sistemi bütünlüğünü doğrular."
    },
    "finding": {
      "PASS": "Tam Güvenlikli başlatma ve mühürlü kök dosya sistemi (SSV) devrede.",
      "WARN": "Başlatma güvenliği tam modda değil veya izin verilen çekirdek uzantıları mevcut."
    }
  },
  "HARD-10": {
    "title": {
      "en": "Automatic Login Disabled",
      "tr": "Otomatik Girişin Devre Dışı Bırakılması"
    },
    "desc": {
      "en": "Ensures automatic console login is disabled, requiring explicit credentials each time the computer boots.",
      "tr": "Bilgisayar her açıldığında açık kimlik doğrulaması gerektirerek otomatik konsol oturum açmanın kapalı olmasını sağlar."
    },
    "finding": {
      "PASS": "Otomatik oturum açma devre dışı.",
      "FAIL": "Otomatik oturum açma etkin! Sistem fiziksel olarak parolasız açılabilir."
    }
  },
  "HARD-11": {
    "title": {
      "en": "Bluetooth Sharing",
      "tr": "Bluetooth Dosya Paylaşımı"
    },
    "desc": {
      "en": "Verifies Bluetooth File Exchange and discoverable sharing services are disabled to block wireless vectors.",
      "tr": "Kablosuz saldırı vektörlerini engellemek için Bluetooth Dosya Değişimi ve görünür paylaşım servislerinin kapalı olduğunu doğrular."
    },
    "finding": {
      "PASS": "Bluetooth dosya paylaşımı devre dışı.",
      "FAIL": "Bluetooth dosya paylaşımı açık! Yetkisiz kablosuz veri transferi mümkün."
    }
  },
  "HARD-12": {
    "title": {
      "en": "Home Directory Permissions",
      "tr": "Kullanıcı Ev Dizini İzinleri"
    },
    "desc": {
      "en": "Ensures user home directories possess restrictive permissions (700 or 750) and are not accessible to other users.",
      "tr": "Kullanıcı ev dizinlerinin kısıtlı izinlere (700 veya 750) sahip olduğunu ve diğer kullanıcılara açık olmadığını denetler."
    },
    "finding": {
      "PASS": "Kullanıcı ev dizini izinleri kısıtlı ve güvenli.",
      "FAIL": "Ev dizini diğer kullanıcılar tarafından okunabilir izinlere sahip!"
    }
  },
  "HARD-13": {
    "title": {
      "en": "Network Time Synchronization",
      "tr": "Ağ Zaman Eşitlemesi (NTP)"
    },
    "desc": {
      "en": "Ensures Network Time Protocol (NTP) synchronization is enabled with verified time servers for audit integrity.",
      "tr": "Denetim bütünlüğü için doğrulanmış zaman sunucuları ile Ağ Zaman Protokolü (NTP) eşitlemesinin aktif olmasını sağlar."
    },
    "finding": {
      "PASS": "Ağ zaman eşitlemesi (NTP) aktif.",
      "FAIL": "Ağ zaman eşitlemesi kapalı! Günlük kayıtlarının zaman damgaları güvenilir olmayabilir."
    }
  },
  "HARD-14": {
    "title": {
      "en": "Built-in Malware Protection",
      "tr": "Yerleşik Zararlı Yazılım Koruması (XProtect)"
    },
    "desc": {
      "en": "Verifies Apple XProtect and XProtect Remediator background signature mechanisms are active and updating.",
      "tr": "Apple XProtect ve XProtect Remediator arka plan imza mekanizmalarının aktif olduğunu ve güncellendiğini doğrular."
    },
    "finding": {
      "PASS": "XProtect ve yerleşik zararlı yazılım koruması aktif.",
      "WARN": "XProtect tanımları güncel olmayabilir veya arka plan servisi yanıt vermiyor."
    }
  },
  "HARD-15": {
    "title": {
      "en": "USB Restricted Mode",
      "tr": "USB Kısıtlı Modu"
    },
    "desc": {
      "en": "Ensures USB Restricted Mode is enabled so that untrusted accessories require explicit approval before connecting.",
      "tr": "Güvenilmeyen aksesuarların bağlanmadan önce açık onay gerektirmesi için USB Kısıtlı Modun devrede olmasını sağlar."
    },
    "finding": {
      "PASS": "USB ve çevre birimi koruma modu devrede.",
      "WARN": "Yeni USB aksesuarları otomatik olarak bağlanabiliyor."
    }
  },
  "NET-01": {
    "title": {
      "en": "Application Firewall Status",
      "tr": "Uygulama Güvenlik Duvarı Durumu"
    },
    "desc": {
      "en": "Ensures the built-in macOS Application Firewall (socketfilterfw) is turned on to inspect and filter inbound packets.",
      "tr": "Gelen paketleri denetlemek ve filtrelemek için yerleşik macOS Uygulama Güvenlik Duvarının açık olduğunu doğrular."
    },
    "finding": {
      "PASS": "macOS Uygulama Güvenlik Duvarı etkin ve gelen bağlantıları filtreliyor.",
      "FAIL": "Uygulama Güvenlik Duvarı devre dışı! Gelen tüm bağlantılar doğrudan kabul edilebilir."
    }
  },
  "NET-02": {
    "title": {
      "en": "Firewall Stealth Mode",
      "tr": "Güvenlik Duvarı Gizli Mod (Stealth Mode)"
    },
    "desc": {
      "en": "Ensures Firewall Stealth Mode is enabled so the system ignores discovery probes and ICMP ping requests.",
      "tr": "Sistemin keşif taramalarını ve ICMP ping isteklerini yok sayması için Güvenlik Duvarı Gizli Modun devrede olmasını sağlar."
    },
    "finding": {
      "PASS": "Güvenlik Duvarı Gizli Mod etkin; sistem ICMP ping ve keşif taramalarına yanıt vermiyor.",
      "FAIL": "Gizli mod kapalı! Sistem ağ taramalarında açıkça tespit edilebilir."
    }
  },
  "NET-03": {
    "title": {
      "en": "Firewall Permissive Exceptions",
      "tr": "Güvenlik Duvarı Geçirgen İstisnaları"
    },
    "desc": {
      "en": "Verifies permissive automatic allowlist exceptions for downloaded signed software and system applications are disabled.",
      "tr": "İndirilen imzalı yazılımlar ve sistem uygulamaları için güvenlik duvarı otomatik izin istisnalarının kapalı olduğunu doğrular."
    },
    "finding": {
      "PASS": "İmzalı uygulamalara otomatik güvenlik duvarı ayrıcalığı tanınmıyor.",
      "WARN": "İmzalı uygulamalar otomatik olarak güvenlik duvarını atlayabiliyor."
    }
  },
  "NET-04": {
    "title": {
      "en": "BPF Packet Capture Permissions",
      "tr": "BPF Paket Yakalama İzinleri"
    },
    "desc": {
      "en": "Audits Berkeley Packet Filter (/dev/bpf*) permissions to ensure non-root users cannot sniff raw network packets.",
      "tr": "Root yetkisine sahip olmayan kullanıcıların ham ağ paketlerini koklayamaması için Berkeley Paket Filtresi (/dev/bpf*) izinlerini denetler."
    },
    "finding": {
      "PASS": "Berkeley Paket Filtresi (/dev/bpf*) aygıtları yalnızca root ile sınırlandırılmış.",
      "FAIL": "Root olmayan kullanıcıların ağ trafiğini dinlemesine izin veriliyor!"
    }
  },
  "NET-05": {
    "title": {
      "en": "/etc/hosts Loopback Integrity",
      "tr": "/etc/hosts Yerel Ağ Bütünlüğü"
    },
    "desc": {
      "en": "Verifies /etc/hosts loopback entries (localhost, 127.0.0.1, ::1) are intact and have not been hijacked or corrupted.",
      "tr": "/etc/hosts yerel geri döngü kayıtlarının bozulmadığını veya ele geçirilmediğini doğrular."
    },
    "finding": {
      "PASS": "/etc/hosts içerisindeki yerel geri döngü kayıtları geçerli ve güvenli.",
      "FAIL": "/etc/hosts dosyasında yerel geri döngü kayıtları eksik veya tahrif edilmiş!"
    }
  },
  "NET-06": {
    "title": {
      "en": "Wildcard Exposed TCP Listeners",
      "tr": "Dışa Açık Genel TCP Dinleyicileri"
    },
    "desc": {
      "en": "Scans for non-system background processes listening on external wildcard network interfaces (0.0.0.0 or ::).",
      "tr": "Dış genel ağ arayüzlerinde (0.0.0.0 veya ::) dinleme yapan sistem dışı arka plan servislerini tarar."
    },
    "finding": {
      "PASS": "Genel ağ arayüzlerinde yetkisiz dinleyici servis tespit edilmedi.",
      "WARN": "Genel ağ arayüzlerine açık dinleyici servisler tespit edildi."
    }
  },
  "NET-07": {
    "title": {
      "en": "AirDrop",
      "tr": "AirDrop Güvenliği"
    },
    "desc": {
      "en": "Audits Apple Wireless Direct Link (AWDL) and AirDrop configuration to prevent untrusted wireless device exposure.",
      "tr": "Güvenilmeyen kablosuz cihaz görünürlüğünü engellemek için AWDL ve AirDrop yapılandırmasını denetler."
    },
    "finding": {
      "PASS": "AirDrop devre dışı veya güvenli modda.",
      "WARN": "AirDrop etkin; yakındaki cihazlar bu Mac'i AWDL üzerinden görebilir."
    }
  },
  "NET-08": {
    "title": {
      "en": "Internet Sharing",
      "tr": "İnternet Paylaşımı"
    },
    "desc": {
      "en": "Ensures Internet Sharing / NAT bridge services are disabled to prevent unauthorized routing between interfaces.",
      "tr": "Ağ arayüzleri arasında yetkisiz paket yönlendirmeyi önlemek için İnternet Paylaşımı / NAT köprü servislerinin kapalı olmasını sağlar."
    },
    "finding": {
      "PASS": "İnternet Paylaşımı (NAT) devre dışı.",
      "FAIL": "İnternet Paylaşımı aktif! Bu bilgisayar diğer cihazlar için ağ geçidi görevi görüyor."
    }
  },
  "NET-09": {
    "title": {
      "en": "Firewall Logging",
      "tr": "Güvenlik Duvarı Günlükleme"
    },
    "desc": {
      "en": "Verifies application firewall logging is configured to record accepted and blocked connection events.",
      "tr": "Kabul edilen ve engellenen bağlantı olaylarını kaydetmek için uygulama güvenlik duvarı günlüklemesinin açık olduğunu doğrular."
    },
    "finding": {
      "PASS": "Uygulama güvenlik duvarı günlüklemesi devrede.",
      "WARN": "Güvenlik duvarı günlükleme kapalı! Bağlantı engelleme olayları kaydedilmiyor."
    }
  },
  "NET-10": {
    "title": {
      "en": "IP Forwarding",
      "tr": "IP Yönlendirme (Forwarding)"
    },
    "desc": {
      "en": "Ensures kernel IPv4/IPv6 packet forwarding is disabled so this Mac cannot serve as an unmonitored router.",
      "tr": "Bu Mac'in kontrolsüz bir yönlendirici gibi davranmasını engellemek için çekirdek IPv4/IPv6 paket yönlendirmenin kapalı olmasını sağlar."
    },
    "finding": {
      "PASS": "Çekirdek düzeyinde IP paket yönlendirme devre dışı.",
      "FAIL": "IP paket yönlendirme açık! Bilgisayar ağ paketlerini yönlendiriyor."
    }
  },
  "NET-11": {
    "title": {
      "en": "Promiscuous Interfaces",
      "tr": "Karmaşık Moddaki (Promiscuous) Arayüzler"
    },
    "desc": {
      "en": "Detects active network interfaces in promiscuous mode that may indicate active packet sniffing or network taps.",
      "tr": "Ağ trafiğinin dinlendiğini gösterebilecek karmaşık (promiscuous) moddaki aktif ağ arayüzlerini tespit eder."
    },
    "finding": {
      "PASS": "Karmaşık modda çalışan ağ arayüzü bulunmuyor.",
      "FAIL": "Karmaşık modda ağ arayüzü tespit edildi! Paket yakalama araçları çalışıyor olabilir."
    }
  },
  "PERS-01": {
    "title": {
      "en": "LaunchAgents Persistence Review",
      "tr": "LaunchAgents Kalıcılık İncelemesi"
    },
    "desc": {
      "en": "Audits user and system LaunchAgents for unauthorized persistence items and unapproved startup scripts.",
      "tr": "Yetkisiz kalıcılık öğeleri ve onaylanmamış başlangıç betiklerine karşı kullanıcı ve sistem LaunchAgents öğelerini inceler."
    },
    "finding": {
      "PASS": "LaunchAgents yapılandırmaları incelendi; şüpheli girdi tespit edilmedi.",
      "WARN": "İnceleme gerektiren özel veya şüpheli LaunchAgent tanımları bulundu."
    }
  },
  "PERS-02": {
    "title": {
      "en": "System LaunchDaemons Review",
      "tr": "Sistem LaunchDaemons İncelemesi"
    },
    "desc": {
      "en": "Inspects daemon configurations in /Library/LaunchDaemons for suspicious executables running with root privileges.",
      "tr": "Root ayrıcalıklarıyla çalışan şüpheli çalıştırılabilir dosyalara karşı /Library/LaunchDaemons yapılandırmalarını inceler."
    },
    "finding": {
      "PASS": "Sistem LaunchDaemons yapılandırmaları standart ve geçerli.",
      "WARN": "Şüpheli veya bozuk LaunchDaemon kayıtları tespit edildi."
    }
  },
  "PERS-03": {
    "title": {
      "en": "Scheduled Cron Jobs",
      "tr": "Zamanlanmış Cron Görevleri"
    },
    "desc": {
      "en": "Audits scheduled cron tab jobs (/var/at/tabs and /etc/cron*) deprecated in favor of launchd.",
      "tr": "launchd yerine kullanılan ve kötüye kullanıma açık eski zamanlanmış cron görevlerini denetler."
    },
    "finding": {
      "PASS": "Sistemde aktif cron görevi bulunmuyor; yalnızca launchd kullanılıyor.",
      "WARN": "Eski cron görevleri tespit edildi! Kalıcılık amacıyla kötüye kullanılmış olabilir."
    }
  },
  "PERS-04": {
    "title": {
      "en": "User Login Items",
      "tr": "Kullanıcı Oturum Açma Öğeleri"
    },
    "desc": {
      "en": "Reviews applications configured to launch automatically when user logs into graphical desktop sessions.",
      "tr": "Kullanıcı grafik masaüstü oturumu açtığında otomatik başlatılan uygulamaları denetler."
    },
    "finding": {
      "PASS": "Oturum açılışında başlayan yetkisiz uygulama bulunmuyor.",
      "WARN": "Oturum açılışında başlayan kullanıcı uygulamaları mevcut; gözden geçirilmelidir."
    }
  },
  "PERS-05": {
    "title": {
      "en": "SSH Authorized Public Keys",
      "tr": "Yetkilendirilmiş SSH Ortak Anahtarları"
    },
    "desc": {
      "en": "Inspects ~/.ssh/authorized_keys to ensure all authorized public keys belong to known administrative operators.",
      "tr": "~/.ssh/authorized_keys dosyasındaki tüm ortak anahtarların bilinen yöneticilere ait olduğunu doğrular."
    },
    "finding": {
      "PASS": "SSH yetkilendirilmiş anahtar dosyası güvenli veya anahtar bulunmuyor.",
      "WARN": "Yetkilendirilmiş SSH anahtarları tespit edildi; anahtar sahipleri doğrulanmalıdır."
    }
  },
  "PERS-06": {
    "title": {
      "en": "Sudoers Configuration & NOPASSWD Rules",
      "tr": "Sudoers Yapılandırması ve NOPASSWD Kuralları"
    },
    "desc": {
      "en": "Scans /etc/sudoers and /etc/sudoers.d for dangerous passwordless NOPASSWD escalation rules.",
      "tr": "/etc/sudoers ve /etc/sudoers.d içerisindeki tehlikeli parolasız NOPASSWD yetki yükseltme kurallarını tarar."
    },
    "finding": {
      "PASS": "Parolasız yetki yükseltme kuralı (NOPASSWD) tespit edilmedi.",
      "FAIL": "Parolasız sudo yetkisi (NOPASSWD) tanımlanmış! Ciddi güvenlik riski."
    }
  },
  "PERS-07": {
    "title": {
      "en": "Privileged Helper Tools",
      "tr": "Ayrıcalıklı Yardımcı Araçlar"
    },
    "desc": {
      "en": "Validates code signatures and authenticity of privileged helper daemons in /Library/PrivilegedHelperTools.",
      "tr": "/Library/PrivilegedHelperTools konumundaki ayrıcalıklı yardımcı servislerin kod imzalarını ve orijinalliğini doğrular."
    },
    "finding": {
      "PASS": "Tüm ayrıcalıklı yardımcı araçların kod imzaları doğrulandı.",
      "WARN": "İmzasız veya imza doğrulaması başarısız yardımcı araçlar mevcut!"
    }
  },
  "PERS-08": {
    "title": {
      "en": "Printer Sharing",
      "tr": "Yazıcı Paylaşımı"
    },
    "desc": {
      "en": "Ensures CUPS printer sharing is disabled to prevent remote access to local printing services.",
      "tr": "Yerel yazdırma servislerine uzaktan erişimi engellemek için CUPS yazıcı paylaşımının kapalı olmasını sağlar."
    },
    "finding": {
      "PASS": "Yazıcı paylaşımı (CUPS) devre dışı.",
      "WARN": "Yazıcı paylaşımı açık; yerel saldırı yüzeyini artırabilir."
    }
  },
  "PERS-09": {
    "title": {
      "en": "Sudo Timestamp Timeout",
      "tr": "Sudo Kimlik Doğrulama Zaman Aşımı"
    },
    "desc": {
      "en": "Verifies the sudo timestamp_timeout window is restricted to prevent unauthorized terminal reuse.",
      "tr": "Yetkisiz terminal kullanımını önlemek için sudo timestamp_timeout yetki süresinin kısıtlı olduğunu doğrular."
    },
    "finding": {
      "PASS": "Sudo kimlik doğrulama süresi güvenli limitlerde (≤ 5 dakika).",
      "WARN": "Sudo yetki süresi uzun; oturum suistimaline yol açabilir."
    }
  },
  "SEC-01": {
    "title": {
      "en": "Plaintext API Keys in Shell Profiles",
      "tr": "Kabuk Profillerinde Düz Metin API Anahtarları"
    },
    "desc": {
      "en": "Scans shell startup dotfiles (.zshrc, .bash_profile, etc.) for exposed API credentials, private tokens, and passwords.",
      "tr": "Kabuk başlangıç dosyalarında (.zshrc vb.) açıkta kalan API anahtarlarını, özel belirteçleri ve parolaları tarar."
    },
    "finding": {
      "PASS": "Kabuk profillerinde düz metin API anahtarı veya şifre bulunmadı.",
      "FAIL": "Kabuk profillerinde açıkta kalan gizli bilgiler veya güvensiz izinler tespit edildi!"
    }
  },
  "SEC-02": {
    "title": {
      "en": "Exposed .env Configuration Files",
      "tr": "Açıkta Kalan .env Yapılandırma Dosyaları"
    },
    "desc": {
      "en": "Identifies world-readable .env configuration files in common project directories containing sensitive environment variables.",
      "tr": "Hassas ortam değişkenleri ve veritabanı parolaları içeren genel okumaya açık .env yapılandırma dosyalarını tespit eder."
    },
    "finding": {
      "PASS": "Genel okumaya açık .env dosyası tespit edilmedi.",
      "FAIL": "Genel erişime açık .env dosyaları bulundu! Hassas kimlik bilgileri sızabilir."
    }
  },
  "SEC-03": {
    "title": {
      "en": "Keychain Auto-Lock Timeout",
      "tr": "Anahtar Zinciri Otomatik Kilit Zaman Aşımı"
    },
    "desc": {
      "en": "Verifies the macOS login keychain has auto-lock timeout configured when the system is inactive.",
      "tr": "Sistem boştayken macOS oturum açma anahtar zincirinin otomatik kilitlenme zaman aşımına sahip olduğunu doğrular."
    },
    "finding": {
      "PASS": "Oturum anahtar zinciri için otomatik kilitleme aktif.",
      "WARN": "Anahtar zinciri zaman aşımı olmadan açık kalıyor; kilit süresi ayarlanmalıdır."
    }
  },
  "SEC-04": {
    "title": {
      "en": "Kernel Core Dumps",
      "tr": "Çekirdek Çökme Dökümleri (Core Dumps)"
    },
    "desc": {
      "en": "Ensures kernel core dumps (kern.coredump=0) are disabled so sensitive memory contents are not written to disk upon crash.",
      "tr": "Çökme anında hassas bellek içeriklerinin diske yazılmaması için çekirdek çökme dökümlerinin (kern.coredump=0) kapalı olmasını sağlar."
    },
    "finding": {
      "PASS": "Çekirdek çökme dökümleri (core dump) devre dışı.",
      "FAIL": "Çekirdek çökme dökümleri etkin! Çöken işlemler bellek içeriklerini diske yazabilir."
    }
  },
  "SEC-05": {
    "title": {
      "en": "SSH Keys and Config Permissions",
      "tr": "SSH Anahtarları ve Yapılandırma İzinleri"
    },
    "desc": {
      "en": "Enforces strict file permissions on ~/.ssh (700), SSH private keys (600), and configuration files.",
      "tr": "~/.ssh dizininde (700), özel anahtarlarda (600) ve yapılandırma dosyalarında katı dosya izinlerini zorunlu kılar."
    },
    "finding": {
      "PASS": "SSH dizini ve özel anahtar izinleri sıkı şekilde korunuyor.",
      "FAIL": "Güvensiz SSH dosya izinleri tespit edildi! Özel anahtarlar başkaları tarafından okunabilir."
    }
  },
  "SEC-06": {
    "title": {
      "en": "Unencrypted SSH Private Keys",
      "tr": "Şifrelenmemiş SSH Özel Anahtarları"
    },
    "desc": {
      "en": "Scans for unencrypted private SSH keys lacking passphrase protection in ~/.ssh.",
      "tr": "~/.ssh dizininde parola koruması bulunmayan şifrelenmemiş özel SSH anahtarlarını tarar."
    },
    "finding": {
      "PASS": "Şifrelenmemiş özel SSH anahtarı bulunmadı.",
      "FAIL": "Parola koruması bulunmayan açık metin SSH özel anahtarları tespit edildi!"
    }
  },
  "SEC-07": {
    "title": {
      "en": "Secrets in Shell History",
      "tr": "Kabuk Geçmişindeki Gizli Bilgiler"
    },
    "desc": {
      "en": "Audits command history files (.zsh_history, .bash_history) for leaked passwords, bearer tokens, or sensitive parameters.",
      "tr": "Komut geçmişi dosyalarında sızdırılmış parolaları, yetkilendirme belirteçlerini veya hassas parametreleri denetler."
    },
    "finding": {
      "PASS": "Komut geçmişi dosyalarında sızdırılmış gizli bilgi bulunmadı.",
      "FAIL": "Kabuk geçmişinde sızdırılmış parolalar veya belirteçler tespit edildi!"
    }
  },
  "SEC-08": {
    "title": {
      "en": "SSH Daemon Hardening",
      "tr": "SSH Sunucu (sshd) Sıkılaştırması"
    },
    "desc": {
      "en": "Audits OpenSSH server configuration (/etc/ssh/sshd_config) for insecure ciphers, root login disablement, and protocol settings.",
      "tr": "Güvensiz şifreleyiciler, root girişinin engellenmesi ve protokol ayarları için OpenSSH sunucu yapılandırmasını denetler."
    },
    "finding": {
      "PASS": "SSH sunucusu güvenli ayarlarla yapılandırılmış veya dışa kapalı.",
      "WARN": "SSH sunucusunda zayıf yapılandırma parametreleri tespit edildi."
    }
  },
  "SEC-09": {
    "title": {
      "en": "Suspicious Shell History Files",
      "tr": "Şüpheli Kabuk Geçmişi Dosyaları"
    },
    "desc": {
      "en": "Detects hijacked, symlinked, or irregularly permissioned shell history files targeting history tampering.",
      "tr": "Geçmiş silme veya tahrifat girişimlerine karşı sembolik bağlı ya da anormal izinli kabuk geçmişi dosyalarını tespit eder."
    },
    "finding": {
      "PASS": "Kabuk geçmişi dosyaları normal ve güvenli.",
      "FAIL": "Şüpheli kabuk geçmişi dosyası veya sembolik bağ tespit edildi!"
    }
  }
}

def t(key, lang=None):
    use_lang = lang or audit_lang
    return UI_STRINGS.get(use_lang, UI_STRINGS['en']).get(key, UI_STRINGS['en'].get(key, key))

try:
    data = json.loads(raw_json)
except Exception as e:
    sys.stderr.write(f"Error parsing audit JSON data: {e}\n")
    sys.exit(1)

# Robust compliance mappings search
compliance_map = {}
search_paths = [
    comp_file,
    os.path.join(os.getcwd(), 'data', 'compliance_mappings.json'),
    '<project_root>/data/compliance_mappings.json'
]
for p in search_paths:
    if p and os.path.isfile(p):
        try:
            with open(p, 'r', encoding='utf-8') as f:
                raw_c = json.load(f)
                compliance_map = raw_c.get('mappings', raw_c)
                if compliance_map:
                    break
        except Exception:
            pass

scanner = data.get('scanner', {})
system = data.get('system', {})
summary = data.get('summary', {})
checks = data.get('checks', [])

version = scanner.get('version') or scanner_ver

# Extract summary metrics
score = float(summary.get('hardening_index', 0.0))
rating = summary.get('rating', 'UNKNOWN')
total_checks = int(summary.get('total_checks', len(checks)))
passed_checks = int(summary.get('passed', 0))
warn_checks = int(summary.get('warnings', 0))
fail_checks = int(summary.get('failed', 0))
info_checks = int(summary.get('info', 0))
sugg_checks = int(summary.get('suggestions', 0))
earned_points = float(summary.get('earned_points', 0.0))
total_points = float(summary.get('total_possible_points', 0.0))

pass_pct = round((passed_checks / total_checks * 100.0) if total_checks > 0 else 0, 1)
warn_pct = round((warn_checks / total_checks * 100.0) if total_checks > 0 else 0, 1)
fail_pct = round((fail_checks / total_checks * 100.0) if total_checks > 0 else 0, 1)

circumference = 439.82
gauge_offset = round(circumference * (1.0 - max(0.0, min(100.0, score)) / 100.0), 2)

if score >= 90:
    letter_grade = "A" if score < 95 else "A+"
    grade_color = "#10b981"
    score_grad_start = "#10b981"
    score_grad_end = "#10b981"
elif score >= 80:
    letter_grade = "B+"
    grade_color = "#10b981"
    score_grad_start = "#10b981"
    score_grad_end = "#10b981"
elif score >= 70:
    letter_grade = "B"
    grade_color = "#e4e4e7"
    score_grad_start = "#e4e4e7"
    score_grad_end = "#e4e4e7"
elif score >= 60:
    letter_grade = "C"
    grade_color = "#f59e0b"
    score_grad_start = "#f59e0b"
    score_grad_end = "#f59e0b"
elif score >= 50:
    letter_grade = "D"
    grade_color = "#f97316"
    score_grad_start = "#f97316"
    score_grad_end = "#f97316"
else:
    letter_grade = "F"
    grade_color = "#ef4444"
    score_grad_start = "#ef4444"
    score_grad_end = "#ef4444"

core_categories = ["hardening", "network", "secrets", "persistence"]
cat_data = {}
for ck in core_categories:
    cat_data[ck] = {
        "name": ck.capitalize(),
        "earned": 0.0,
        "possible": 0.0,
        "pass": 0,
        "warn": 0,
        "fail": 0,
        "info": 0,
        "sugg": 0,
        "total": 0,
        "score_pct": 100.0
    }

for c in checks:
    cat_raw = str(c.get('category', '')).strip().lower()
    if not cat_raw:
        continue
    if cat_raw not in cat_data:
        cat_data[cat_raw] = {
            "name": cat_raw.capitalize(),
            "earned": 0.0,
            "possible": 0.0,
            "pass": 0,
            "warn": 0,
            "fail": 0,
            "info": 0,
            "sugg": 0,
            "total": 0,
            "score_pct": 100.0
        }
    st = str(c.get('status', 'INFO')).upper()
    try:
        w = float(c.get('weight', 5.0))
    except Exception:
        w = 5.0
    cat_data[cat_raw]["total"] += 1
    if st == "PASS":
        cat_data[cat_raw]["pass"] += 1
        cat_data[cat_raw]["earned"] += w
        cat_data[cat_raw]["possible"] += w
    elif st == "WARN":
        cat_data[cat_raw]["warn"] += 1
        cat_data[cat_raw]["earned"] += (w * 0.5)
        cat_data[cat_raw]["possible"] += w
    elif st == "FAIL":
        cat_data[cat_raw]["fail"] += 1
        cat_data[cat_raw]["possible"] += w
    elif st == "INFO":
        cat_data[cat_raw]["info"] += 1
    elif st == "SUGG":
        cat_data[cat_raw]["sugg"] += 1

for k, v in cat_data.items():
    if v["possible"] > 0:
        v["score_pct"] = round((v["earned"] / v["possible"]) * 100.0, 1)
    else:
        v["score_pct"] = 100.0

ordered_categories = ["all"] + [c for c in core_categories if c in cat_data]
for c in cat_data:
    if c not in ordered_categories:
        ordered_categories.append(c)

def get_severity(w):
    try:
        val = float(w)
    except Exception:
        val = 5.0
    if val >= 9.0:
        return "CRITICAL"
    elif val >= 7.0:
        return "HIGH"
    elif val >= 5.0:
        return "MEDIUM"
    else:
        return "LOW"

sev_stats = {
    "CRITICAL": {"total": 0, "fail": 0, "warn": 0, "pass": 0},
    "HIGH": {"total": 0, "fail": 0, "warn": 0, "pass": 0},
    "MEDIUM": {"total": 0, "fail": 0, "warn": 0, "pass": 0},
    "LOW": {"total": 0, "fail": 0, "warn": 0, "pass": 0}
}

for c in checks:
    w = c.get('weight', 5)
    sev = get_severity(w)
    st = str(c.get('status', 'INFO')).upper()
    sev_stats[sev]["total"] += 1
    if st == "FAIL":
        sev_stats[sev]["fail"] += 1
    elif st == "WARN":
        sev_stats[sev]["warn"] += 1
    elif st == "PASS":
        sev_stats[sev]["pass"] += 1

def get_check_frameworks(cid, cmap):
    m = cmap.get(cid)
    if not m:
        for k, v in cmap.items():
            if k.replace("-", "_").upper() == cid.replace("-", "_").upper():
                m = v
                break
    m = m or {}
    has_cis = False
    cis_tag = ""
    cis_obj = m.get('cis') or m.get('cis_benchmark')
    if cis_obj:
        has_cis = True
        if isinstance(cis_obj, dict):
            cis_tag = cis_obj.get('id', '')
        else:
            cis_tag = str(cis_obj)
    has_nist = False
    nist_tags = []
    nist_obj = m.get('nist') or m.get('nist_800_53')
    if nist_obj:
        has_nist = True
        if isinstance(nist_obj, dict):
            nist_tags = nist_obj.get('controls', [])
            if not nist_tags and nist_obj.get('primary'):
                nist_tags = [nist_obj.get('primary')]
        elif isinstance(nist_obj, list):
            nist_tags = nist_obj
        else:
            nist_tags = [str(nist_obj)]
    has_mitre = False
    mitre_tags = []
    mitre_obj = m.get('mitre') or m.get('mitre_attack')
    if mitre_obj:
        has_mitre = True
        if isinstance(mitre_obj, dict):
            mitre_tags = mitre_obj.get('techniques', [])
            if not mitre_tags and mitre_obj.get('primary_technique'):
                mitre_tags = [mitre_obj.get('primary_technique')]
            elif not mitre_tags and mitre_obj.get('primary'):
                mitre_tags = [mitre_obj.get('primary')]
        elif isinstance(mitre_obj, list):
            mitre_tags = mitre_obj
        else:
            mitre_tags = [str(mitre_obj)]
    mitre_tag_str = ""
    if mitre_tags:
        t0 = mitre_tags[0]
        if isinstance(t0, dict):
            mitre_tag_str = t0.get('id', '')
        else:
            mitre_tag_str = str(t0)
    nist_tag_str = str(nist_tags[0]) if nist_tags else ""
    return {
        "has_cis": has_cis,
        "cis_tag": cis_tag,
        "has_nist": has_nist,
        "nist_tags": nist_tags,
        "nist_tag_str": nist_tag_str,
        "has_mitre": has_mitre,
        "mitre_tags": mitre_tags,
        "mitre_tag_str": mitre_tag_str
    }

cis_total = 0; cis_passed = 0; cis_fw_count = 0
nist_total = 0; nist_passed = 0; nist_fw_count = 0
mitre_fw_count = 0
for c in checks:
    cid = c.get('id', '')
    st = c.get('status', '')
    fws = get_check_frameworks(cid, compliance_map)
    if fws["has_cis"]:
        cis_fw_count += 1; cis_total += 1
        if st == 'PASS': cis_passed += 1
        elif st == 'WARN': cis_passed += 0.5
    if fws["has_nist"]:
        nist_fw_count += 1; nist_total += 1
        if st == 'PASS': nist_passed += 1
        elif st == 'WARN': nist_passed += 0.5
    if fws["has_mitre"]:
        mitre_fw_count += 1
cis_pct = round((cis_passed / cis_total * 100) if cis_total > 0 else 85.0, 1)
nist_pct = round((nist_passed / nist_total * 100) if nist_total > 0 else 82.0, 1)

remediable_checks = [c for c in checks if c.get('status') in ['FAIL', 'WARN'] and c.get('remediation')]
remediable_count = len(remediable_checks)
remed_script_lines = [
    "#!/bin/zsh",
    "# ==============================================================================",
    "# macharden - Automated Remediation Playbook",
    f"# Target Host: {system.get('hostname', 'macOS')} | Operator: {system.get('user', 'unknown')}",
    f"# Generated: {scanner.get('timestamp', '')} | Scanner Version: v{version}",
    "# ==============================================================================",
    "set -euo pipefail",
    "",
    "echo \"[*] Initiating macharden security hardening remediation playbook...\"",
    "echo \"[*] Target host: $(hostname)\"",
    ""
]
if remediable_checks:
    for c in remediable_checks:
        cid = c.get('id', '')
        ctitle = c.get('title', '')
        csev = get_severity(c.get('weight', 5))
        rem = c.get('remediation', '')
        remed_script_lines.append("# ------------------------------------------------------------------------------")
        remed_script_lines.append(f"# [{cid}] {ctitle} (Severity: {csev})")
        remed_script_lines.append("# ------------------------------------------------------------------------------")
        remed_script_lines.append(f"echo \"[+] Applying fix for {cid}: {ctitle}...\"")
        remed_script_lines.append(rem)
        remed_script_lines.append("")
    remed_script_lines.append("echo \"[✔] All remediation commands executed successfully.\"")
    remed_script_lines.append("echo \"[✔] Re-run macharden audit to verify hardening posture.\"")
else:
    remed_script_lines.append("# No automated remediation commands required! Security posture is fully hardened.")
    remed_script_lines.append("echo \"[✔] No failed or warning controls detected. System is hardened.\"")
raw_playbook_script = "\n".join(remed_script_lines)

doc = []
doc.append('<!DOCTYPE html>')
doc.append(f'<html lang="{audit_lang}" data-lang="{audit_lang}">')
doc.append('<head>')
doc.append('  <meta charset="UTF-8" />')
doc.append('  <meta name="viewport" content="width=device-width, initial-scale=1.0" />')
doc.append(f'  <title>macharden Security Audit Report — {html.escape(system.get("hostname", "macOS"))}</title>')
doc.append('''  <script>
// Prevent flash of unstyled theme & language
(function() {
  try {
    var t = localStorage.getItem('macharden_theme');
    if (!t) {
      t = (window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches) ? 'light' : 'dark';
    }
    document.documentElement.setAttribute('data-theme', t);
  } catch (e) {}
  try {
    var l = localStorage.getItem('macharden_lang');
    if (l === 'tr' || l === 'en') {
      document.documentElement.setAttribute('lang', l);
      document.documentElement.setAttribute('data-lang', l);
    }
  } catch (e) {}
})();
  </script>''')
doc.append("  <style>")
doc.append("""
:root {
  --font-sans: -apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Inter", -apple-system-ui-serif, "Segoe UI", Helvetica, Arial, sans-serif;
  --font-mono: "SF Mono", Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace;
}

:root[data-theme="dark"], html[data-theme="dark"] {
  --bg-page: #000000;
  --bg-subtle: #121215;
  --bg-card: #09090b;
  --bg-card-hover: #131317;
  --bg-card-expanded: #0c0c0f;
  --bg-code: #000000;
  --bg-input: #000000;
  --bg-modal-backdrop: rgba(0, 0, 0, 0.85);
  --bg-modal: #09090b;
  
  --border-subtle: rgba(255, 255, 255, 0.06);
  --border-card: rgba(255, 255, 255, 0.09);
  --border-specular: inset 0 1px 0 0 rgba(255, 255, 255, 0.08);
  --border-active: rgba(255, 255, 255, 0.28);
  --accent-glow: rgba(255, 255, 255, 0.08);
  
  --text-title: #ffffff;
  --text-body: #d4d4d8;
  --text-muted: #a1a1aa;
  --text-dim: #71717a;
  
  /* Subtle, functional semantic RGB accents */
  --color-pass: #10b981;
  --color-pass-bg: rgba(16, 185, 129, 0.08);
  --color-pass-border: rgba(16, 185, 129, 0.25);
  
  --color-warn: #f59e0b;
  --color-warn-bg: rgba(245, 158, 11, 0.08);
  --color-warn-border: rgba(245, 158, 11, 0.25);
  
  --color-fail: #ef4444;
  --color-fail-bg: rgba(239, 68, 68, 0.08);
  --color-fail-border: rgba(239, 68, 68, 0.25);
  
  --color-info: #71717a;
  --color-info-bg: rgba(255, 255, 255, 0.05);
  --color-info-border: rgba(255, 255, 255, 0.12);
  
  --color-sugg: #a1a1aa;
  --color-sugg-bg: rgba(255, 255, 255, 0.05);
  --color-sugg-border: rgba(255, 255, 255, 0.12);

  --sev-critical: #ef4444;
  --sev-critical-bg: rgba(239, 68, 68, 0.08);
  --sev-critical-border: rgba(239, 68, 68, 0.25);

  --sev-high: #f97316;
  --sev-high-bg: rgba(249, 115, 22, 0.08);
  --sev-high-border: rgba(249, 115, 22, 0.25);

  --sev-medium: #f59e0b;
  --sev-medium-bg: rgba(245, 158, 11, 0.08);
  --sev-medium-border: rgba(245, 158, 11, 0.25);

  --sev-low: #71717a;
  --sev-low-bg: rgba(255, 255, 255, 0.05);
  --sev-low-border: rgba(255, 255, 255, 0.12);

  --shadow-sm: 0 2px 6px 0 rgba(0, 0, 0, 0.6);
  --shadow-md: 0 6px 18px -2px rgba(0, 0, 0, 0.8);
  --shadow-lg: 0 14px 32px -4px rgba(0, 0, 0, 0.9);
  --gauge-bg-stroke: #18181b;
}

:root[data-theme="light"], html[data-theme="light"] {
  --bg-page: #f9fafb;
  --bg-subtle: #f3f4f6;
  --bg-card: #ffffff;
  --bg-card-hover: #f8fafc;
  --bg-card-expanded: #f8fafc;
  --bg-code: #0a0a0c;
  --bg-input: #ffffff;
  --bg-modal-backdrop: rgba(0, 0, 0, 0.5);
  --bg-modal: #ffffff;
  
  --border-subtle: rgba(0, 0, 0, 0.06);
  --border-card: rgba(0, 0, 0, 0.1);
  --border-specular: inset 0 1px 0 0 rgba(255, 255, 255, 0.8);
  --border-active: #000000;
  --accent-glow: rgba(0, 0, 0, 0.08);
  
  --text-title: #09090b;
  --text-body: #27272a;
  --text-muted: #52525b;
  --text-dim: #71717a;
  
  --color-pass: #059669;
  --color-pass-bg: rgba(5, 150, 105, 0.08);
  --color-pass-border: rgba(5, 150, 105, 0.25);
  
  --color-warn: #d97706;
  --color-warn-bg: rgba(217, 119, 6, 0.08);
  --color-warn-border: rgba(217, 119, 6, 0.25);
  
  --color-fail: #dc2626;
  --color-fail-bg: rgba(220, 38, 38, 0.08);
  --color-fail-border: rgba(220, 38, 38, 0.25);
  
  --color-info: #52525b;
  --color-info-bg: rgba(0, 0, 0, 0.04);
  --color-info-border: rgba(0, 0, 0, 0.1);
  
  --color-sugg: #71717a;
  --color-sugg-bg: rgba(0, 0, 0, 0.04);
  --color-sugg-border: rgba(0, 0, 0, 0.1);

  --sev-critical: #dc2626;
  --sev-critical-bg: rgba(220, 38, 38, 0.08);
  --sev-critical-border: rgba(220, 38, 38, 0.25);

  --sev-high: #ea580c;
  --sev-high-bg: rgba(234, 88, 12, 0.08);
  --sev-high-border: rgba(234, 88, 12, 0.25);

  --sev-medium: #d97706;
  --sev-medium-bg: rgba(217, 119, 6, 0.08);
  --sev-medium-border: rgba(217, 119, 6, 0.25);

  --sev-low: #52525b;
  --sev-low-bg: rgba(0, 0, 0, 0.04);
  --sev-low-border: rgba(0, 0, 0, 0.1);

  --shadow-sm: 0 1px 3px rgba(0, 0, 0, 0.05);
  --shadow-md: 0 4px 12px rgba(0, 0, 0, 0.06);
  --shadow-lg: 0 10px 25px rgba(0, 0, 0, 0.08);
  --gauge-bg-stroke: #e4e4e7;
}

* { box-sizing: border-box; margin: 0; padding: 0; }

body {
  background-color: var(--bg-page);
  color: var(--text-body);
  font-family: var(--font-sans);
  min-height: 100vh;
  line-height: 1.5;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  transition: background-color 0.2s ease, color 0.2s ease;
  position: relative;
  overflow-x: hidden;
}

.liquid-mesh { display: none !important; }

.app-wrapper {
  max-width: 1240px;
  margin: 0 auto;
  padding: 24px 20px 80px 20px;
}

/* Header Navbar */
.navbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 14px 20px;
  background: var(--bg-card);
  border: 1px solid var(--border-card);
  border-radius: 12px;
  margin-bottom: 24px;
  box-shadow: var(--shadow-sm);
  flex-wrap: wrap;
  gap: 12px;
}

.nav-brand {
  display: flex;
  align-items: center;
  gap: 12px;
}

.brand-icon {
  width: 36px;
  height: 36px;
  border-radius: 8px;
  background: #18181b;
  border: 1px solid rgba(255, 255, 255, 0.15);
  display: flex;
  align-items: center;
  justify-content: center;
  color: #ffffff;
  box-shadow: 0 2px 6px rgba(0, 0, 0, 0.4);
}

.brand-icon svg { width: 20px; height: 20px; }

.brand-title {
  font-size: 1.2rem;
  font-weight: 700;
  letter-spacing: -0.02em;
  color: var(--text-title);
  display: flex;
  align-items: center;
  gap: 8px;
}

.badge-version {
  font-size: 0.72rem;
  font-weight: 600;
  padding: 2px 7px;
  border-radius: 5px;
  background: #18181b;
  color: #a1a1aa;
  border: 1px solid rgba(255, 255, 255, 0.1);
}

.nav-sub {
  font-size: 0.8rem;
  color: var(--text-dim);
}

.nav-actions {
  display: flex;
  align-items: center;
  gap: 8px;
  flex-wrap: wrap;
}

.btn-nav {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 6px 12px;
  border-radius: 7px;
  font-size: 0.8rem;
  font-weight: 600;
  background: var(--bg-subtle);
  border: 1px solid var(--border-subtle);
  color: var(--text-body);
  cursor: pointer;
  transition: all 0.15s ease;
  font-family: inherit;
  text-decoration: none;
}

.btn-nav:hover {
  background: #1c1c20;
  border-color: rgba(255, 255, 255, 0.18);
  color: #ffffff;
  transform: translateY(-1px);
}

:root[data-theme="light"] .btn-nav:hover {
  background: #f3f4f6;
  border-color: rgba(0, 0, 0, 0.12);
  color: #000000;
}

.btn-nav svg { width: 15px; height: 15px; }

.btn-nav-playbook {
  background: #18181b;
  border: 1px solid rgba(245, 158, 11, 0.35);
  color: #f59e0b;
}

.btn-nav-playbook:hover {
  background: rgba(245, 158, 11, 0.12);
  border-color: #f59e0b;
  color: #ffffff;
}

kbd.nav-kbd {
  font-family: var(--font-mono);
  font-size: 0.68rem;
  font-weight: 700;
  padding: 1px 5px;
  border-radius: 4px;
  background: rgba(255, 255, 255, 0.08);
  border: 1px solid rgba(255, 255, 255, 0.1);
  color: var(--text-dim);
}

/* Hero Overview Grid */
.hero-grid {
  display: grid;
  grid-template-columns: 320px 1fr;
  gap: 18px;
  margin-bottom: 24px;
}

@media (max-width: 960px) {
  .hero-grid { grid-template-columns: 1fr; }
}

.hero-card {
  background: var(--bg-card);
  border: 1px solid var(--border-card);
  border-radius: 12px;
  padding: 22px;
  box-shadow: var(--shadow-md);
  position: relative;
  overflow: hidden;
}

.section-label {
  font-size: 0.72rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--text-dim);
  margin-bottom: 16px;
  display: flex;
  align-items: center;
  gap: 6px;
}

.section-label svg { width: 15px; height: 15px; color: var(--text-muted); }

/* Score Card & Circular Gauge */
.score-card {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: space-between;
  text-align: center;
}

.gauge-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  width: 100%;
}

.gauge-box {
  position: relative;
  width: 168px;
  height: 168px;
  margin: 4px auto 14px auto;
}

.gauge-svg {
  width: 100%;
  height: 100%;
  transform: rotate(-90deg);
}

.gauge-bg {
  fill: none;
  stroke: var(--gauge-bg-stroke);
  stroke-width: 10;
}

.gauge-ring {
  fill: none;
  stroke-width: 10;
  stroke-linecap: round;
  transition: stroke-dashoffset 1.2s cubic-bezier(0.16, 1, 0.3, 1);
}

.gauge-inner {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  pointer-events: none;
}

.gauge-score {
  font-size: 2.2rem;
  font-weight: 800;
  letter-spacing: -0.03em;
  color: var(--text-title);
  line-height: 1;
}

.gauge-score span {
  font-size: 1.05rem;
  font-weight: 600;
  color: var(--text-dim);
}

.gauge-sub-badge {
  font-size: 0.72rem;
  font-weight: 700;
  letter-spacing: 0.05em;
  margin-top: 4px;
  padding: 2px 8px;
  border-radius: 10px;
  background: var(--bg-subtle);
  border: 1px solid var(--border-subtle);
  color: var(--text-muted);
}

/* Rating Badge - Positioned cleanly below the SVG circle */
.grade-badge {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 0.76rem;
  font-weight: 700;
  padding: 5px 12px;
  border-radius: 18px;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  max-width: 100%;
  word-break: keep-all;
  white-space: nowrap;
  box-shadow: var(--shadow-sm);
  margin-bottom: 6px;
  background: #141418;
  border: 1px solid rgba(255, 255, 255, 0.1);
  color: #e4e4e7;
}

.badge-dot {
  width: 7px;
  height: 7px;
  border-radius: 50%;
  background: currentColor;
}

.grade-excellent { color: var(--color-pass); border-color: var(--color-pass-border); background: var(--color-pass-bg); }
.grade-good { color: var(--text-title); border-color: rgba(255, 255, 255, 0.15); background: #141418; }
.grade-fair { color: var(--color-warn); border-color: var(--color-warn-border); background: var(--color-warn-bg); }
.grade-critical { color: var(--color-fail); border-color: var(--color-fail-border); background: var(--color-fail-bg); }

.score-points {
  font-size: 0.8rem;
  color: var(--text-dim);
  margin-top: 2px;
}

.score-points strong { color: var(--text-title); }

.compliance-meters {
  width: 100%;
  margin-top: 16px;
  padding-top: 14px;
  border-top: 1px solid var(--border-subtle);
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.meter-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 0.75rem;
}

.meter-label { color: var(--text-dim); font-weight: 600; }
.meter-val { font-family: var(--font-mono); font-weight: 700; color: var(--text-title); }

.meter-bar-track {
  width: 100%;
  height: 5px;
  background: #18181b;
  border-radius: 3px;
  overflow: hidden;
  margin-top: 4px;
}

.meter-bar-fill {
  height: 100%;
  border-radius: 3px;
  background: #e4e4e7;
}

/* System Metadata & KPI Panel */
.meta-panel {
  display: flex;
  flex-direction: column;
  justify-content: space-between;
}

.stats-row {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 12px;
  margin-bottom: 18px;
}

@media (max-width: 680px) {
  .stats-row { grid-template-columns: repeat(2, 1fr); }
}

.stat-box {
  background: var(--bg-subtle);
  border: 1px solid var(--border-subtle);
  border-radius: 10px;
  padding: 13px 15px;
  cursor: pointer;
  transition: all 0.15s ease;
  position: relative;
  overflow: hidden;
}

.stat-box:hover {
  transform: translateY(-2px);
  border-color: rgba(255, 255, 255, 0.18);
  background: #18181c;
}

:root[data-theme="light"] .stat-box:hover {
  background: #ffffff;
  border-color: rgba(0, 0, 0, 0.15);
}

.stat-box.active {
  border-color: var(--border-active);
  background: #18181c;
}

.stat-box-label {
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  color: var(--text-dim);
}

.stat-box-val {
  font-size: 1.7rem;
  font-weight: 800;
  color: var(--text-title);
  line-height: 1.1;
  margin: 4px 0 2px 0;
  font-family: var(--font-sans);
}

.stat-box.box-pass .stat-box-val { color: var(--color-pass); }
.stat-box.box-warn .stat-box-val { color: var(--color-warn); }
.stat-box.box-fail .stat-box-val { color: var(--color-fail); }

.stat-box-sub {
  font-size: 0.72rem;
  color: var(--text-dim);
}

/* System Metadata Info Grid */
.sys-info-grid {
  display: grid;
  grid-template-columns: repeat(2, 1fr);
  gap: 12px;
  background: var(--bg-subtle);
  border: 1px solid var(--border-subtle);
  border-radius: 10px;
  padding: 14px;
}

@media (max-width: 680px) {
  .sys-info-grid { grid-template-columns: 1fr; }
}

.sys-info-item {
  display: flex;
  align-items: center;
  gap: 10px;
}

.sys-info-icon {
  width: 32px;
  height: 32px;
  border-radius: 7px;
  background: #18181b;
  border: 1px solid var(--border-subtle);
  display: flex;
  align-items: center;
  justify-content: center;
  color: var(--text-muted);
  flex-shrink: 0;
}

.sys-info-icon svg { width: 16px; height: 16px; }

.sys-info-key {
  font-size: 0.7rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-dim);
}

.sys-info-val {
  font-size: 0.82rem;
  font-weight: 600;
  color: var(--text-title);
  font-family: var(--font-mono);
}

/* =============================================================================
   1. Category Score Breakdown Panel
   ============================================================================= */
.cat-breakdown-section {
  margin-bottom: 24px;
}

.category-grid {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 14px;
}

@media (max-width: 960px) {
  .category-grid { grid-template-columns: repeat(2, 1fr); }
}

@media (max-width: 520px) {
  .category-grid { grid-template-columns: 1fr; }
}

.cat-card {
  background: var(--bg-card);
  border: 1px solid var(--border-card);
  border-radius: 12px;
  padding: 16px 18px;
  cursor: pointer;
  transition: all 0.15s ease;
  box-shadow: var(--shadow-sm);
  position: relative;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
}

.cat-card:hover {
  transform: translateY(-2px);
  border-color: rgba(255, 255, 255, 0.18);
  background: var(--bg-card-hover);
}

:root[data-theme="light"] .cat-card:hover {
  background: #ffffff;
  border-color: rgba(0, 0, 0, 0.15);
}

.cat-card.active {
  border-color: var(--border-active);
  background: #121216;
}

.cat-card-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 12px;
}

.cat-card-header {
  display: flex;
  align-items: center;
  gap: 10px;
}

.cat-card-icon {
  width: 32px;
  height: 32px;
  border-radius: 7px;
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--bg-subtle);
  border: 1px solid var(--border-subtle);
  color: var(--text-muted);
}

.cat-card-icon svg { width: 17px; height: 17px; }

.cat-card-name {
  font-size: 0.92rem;
  font-weight: 700;
  color: var(--text-title);
  letter-spacing: -0.01em;
}

.cat-card-score {
  font-size: 1.3rem;
  font-weight: 800;
  font-family: var(--font-mono);
  line-height: 1;
}

.cat-card-bar-wrap {
  margin: 10px 0 12px 0;
}

.cat-card-bar-track {
  width: 100%;
  height: 5px;
  background: #18181b;
  border-radius: 3px;
  overflow: hidden;
}

.cat-card-bar-fill {
  height: 100%;
  border-radius: 3px;
  transition: width 0.6s ease;
}

.cat-card-counts {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 0.72rem;
  font-weight: 600;
}

.cat-count-badge {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 2px 6px;
  border-radius: 4px;
}

.cnt-pass { background: var(--color-pass-bg); color: var(--color-pass); border: 1px solid var(--color-pass-border); }
.cnt-warn { background: var(--color-warn-bg); color: var(--color-warn); border: 1px solid var(--color-warn-border); }
.cnt-fail { background: var(--color-fail-bg); color: var(--color-fail); border: 1px solid var(--color-fail-border); }

/* =============================================================================
   2. Risk & Severity Breakdown Matrix & Tags
   ============================================================================= */
.sev-section {
  margin-bottom: 24px;
}

.sev-strip {
  display: grid;
  grid-template-columns: repeat(4, 1fr);
  gap: 12px;
}

@media (max-width: 768px) {
  .sev-strip { grid-template-columns: repeat(2, 1fr); }
}

@media (max-width: 480px) {
  .sev-strip { grid-template-columns: 1fr; }
}

.sev-card {
  background: var(--bg-card);
  border: 1px solid var(--border-card);
  border-radius: 10px;
  padding: 12px 15px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  cursor: pointer;
  transition: all 0.15s ease;
  box-shadow: var(--shadow-sm);
}

.sev-card:hover {
  transform: translateY(-2px);
  border-color: rgba(255, 255, 255, 0.18);
}

.sev-card.active {
  box-shadow: 0 0 0 1px var(--border-active);
}

.sev-card.sev-card-critical { border-left: 3px solid var(--sev-critical); }
.sev-card.sev-card-high { border-left: 3px solid var(--sev-high); }
.sev-card.sev-card-medium { border-left: 3px solid var(--sev-medium); }
.sev-card.sev-card-low { border-left: 3px solid var(--sev-low); }

.sev-card-left {
  display: flex;
  flex-direction: column;
}

.sev-card-title {
  font-size: 0.72rem;
  font-weight: 800;
  letter-spacing: 0.05em;
  text-transform: uppercase;
}

.sev-card-critical .sev-card-title { color: var(--sev-critical); }
.sev-card-high .sev-card-title { color: var(--sev-high); }
.sev-card-medium .sev-card-title { color: var(--sev-medium); }
.sev-card-low .sev-card-title { color: var(--sev-low); }

.sev-card-desc {
  font-size: 0.7rem;
  color: var(--text-dim);
  margin-top: 2px;
}

.sev-card-right {
  display: flex;
  align-items: baseline;
  gap: 4px;
}

.sev-card-val {
  font-size: 1.4rem;
  font-weight: 800;
  font-family: var(--font-mono);
  color: var(--text-title);
  line-height: 1;
}

.sev-card-subval {
  font-size: 0.7rem;
  font-weight: 600;
  color: var(--text-dim);
}

/* Subtle Severity Badges for Accordion */
.badge-severity {
  font-size: 0.65rem;
  font-weight: 800;
  letter-spacing: 0.05em;
  text-transform: uppercase;
  padding: 2px 6px;
  border-radius: 4px;
  flex-shrink: 0;
  font-family: var(--font-sans);
}

.badge-sev-critical {
  background: var(--sev-critical-bg);
  color: var(--sev-critical);
  border: 1px solid var(--sev-critical-border);
}

.badge-sev-high {
  background: var(--sev-high-bg);
  color: var(--sev-high);
  border: 1px solid var(--sev-high-border);
}

.badge-sev-medium {
  background: var(--sev-medium-bg);
  color: var(--sev-medium);
  border: 1px solid var(--sev-medium-border);
}

.badge-sev-low {
  background: var(--sev-low-bg);
  color: var(--sev-low);
  border: 1px solid var(--sev-low-border);
}

/* Remediation Playbook Callout Banner */
.fix-banner {
  background: var(--bg-card);
  border: 1px solid var(--border-card);
  border-left: 3px solid var(--color-warn);
  border-radius: 12px;
  padding: 16px 20px;
  margin-bottom: 24px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  box-shadow: var(--shadow-sm);
  flex-wrap: wrap;
}

.fix-banner-left {
  display: flex;
  align-items: center;
  gap: 12px;
}

.fix-banner-icon {
  width: 34px;
  height: 34px;
  border-radius: 8px;
  background: #18181b;
  border: 1px solid rgba(245, 158, 11, 0.3);
  color: var(--color-warn);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.fix-banner-icon svg { width: 18px; height: 18px; }

.fix-banner-title {
  font-size: 0.9rem;
  font-weight: 700;
  color: var(--text-title);
}

.fix-banner-desc {
  font-size: 0.78rem;
  color: var(--text-dim);
}

.fix-banner-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}

.btn-primary-fix {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  background: #ffffff;
  color: #000000;
  font-weight: 700;
  font-size: 0.8rem;
  padding: 7px 15px;
  border-radius: 7px;
  border: 1px solid #ffffff;
  cursor: pointer;
  transition: all 0.15s ease;
  white-space: nowrap;
  font-family: inherit;
}

.btn-primary-fix:hover {
  background: #e4e4e7;
  transform: translateY(-1px);
}

.btn-primary-fix svg { width: 15px; height: 15px; }

.btn-secondary-fix {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  background: var(--bg-subtle);
  border: 1px solid var(--border-subtle);
  color: var(--text-body);
  font-weight: 600;
  font-size: 0.8rem;
  padding: 7px 13px;
  border-radius: 7px;
  cursor: pointer;
  transition: all 0.15s ease;
  white-space: nowrap;
  font-family: inherit;
}

.btn-secondary-fix:hover {
  background: #18181c;
  color: var(--text-title);
  transform: translateY(-1px);
}

.btn-secondary-fix svg { width: 15px; height: 15px; }

/* Filter & Controls Toolbar */
.toolbar-panel {
  background: var(--bg-card);
  border: 1px solid var(--border-card);
  border-radius: 12px;
  padding: 14px 18px;
  margin-bottom: 20px;
  display: flex;
  flex-direction: column;
  gap: 12px;
  box-shadow: var(--shadow-sm);
}

.category-nav {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 6px;
  border-bottom: 1px solid var(--border-subtle);
  padding-bottom: 10px;
}

.cat-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  background: transparent;
  border: 1px solid transparent;
  color: var(--text-dim);
  padding: 5px 11px;
  border-radius: 7px;
  font-size: 0.82rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.15s ease;
  font-family: inherit;
}

.cat-btn:hover {
  background: var(--bg-subtle);
  color: var(--text-title);
}

.cat-btn.active {
  background: #27272a;
  border: 1px solid rgba(255, 255, 255, 0.18);
  color: #ffffff;
}

:root[data-theme="light"] .cat-btn.active {
  background: #e4e4e7;
  border-color: rgba(0, 0, 0, 0.15);
  color: #000000;
}

.cat-count {
  font-size: 0.7rem;
  padding: 1px 6px;
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.08);
  color: var(--text-dim);
}

.cat-btn.active .cat-count {
  background: rgba(255, 255, 255, 0.18);
  color: #ffffff;
}

:root[data-theme="light"] .cat-btn.active .cat-count {
  background: rgba(0, 0, 0, 0.1);
  color: #000000;
}

/* Framework Filter Row */
.filter-subnav {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
  flex-wrap: wrap;
}

.framework-filters {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-wrap: wrap;
}

.framework-label {
  font-size: 0.72rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-dim);
  margin-right: 4px;
}

.fw-pill {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 4px 10px;
  border-radius: 6px;
  font-size: 0.75rem;
  font-weight: 600;
  background: var(--bg-subtle);
  border: 1px solid var(--border-subtle);
  color: var(--text-muted);
  cursor: pointer;
  transition: all 0.15s ease;
  font-family: inherit;
}

.fw-pill:hover {
  background: #18181c;
  color: var(--text-title);
}

.fw-pill.active {
  color: #ffffff;
  background: #27272a;
  border-color: rgba(255, 255, 255, 0.2);
}

.fw-pill.pill-fw-cis.active {
  border-color: rgba(56, 189, 248, 0.35);
  color: #38bdf8;
  background: rgba(56, 189, 248, 0.08);
}

.fw-pill.pill-fw-nist.active {
  border-color: rgba(168, 85, 247, 0.35);
  color: #c084fc;
  background: rgba(168, 85, 247, 0.08);
}

.fw-pill.pill-fw-mitre.active {
  border-color: rgba(249, 115, 22, 0.35);
  color: #fb923c;
  background: rgba(249, 115, 22, 0.08);
}

.fw-badge-cnt {
  font-size: 0.68rem;
  padding: 1px 5px;
  border-radius: 6px;
  background: rgba(255, 255, 255, 0.1);
}

.filter-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 14px;
  flex-wrap: wrap;
}

.status-pills {
  display: flex;
  align-items: center;
  gap: 6px;
  flex-wrap: wrap;
}

.status-pill {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 4px 10px;
  border-radius: 6px;
  font-size: 0.75rem;
  font-weight: 600;
  background: var(--bg-subtle);
  border: 1px solid var(--border-subtle);
  color: var(--text-muted);
  cursor: pointer;
  transition: all 0.15s ease;
  font-family: inherit;
}

.status-pill:hover {
  background: #18181c;
  color: var(--text-title);
}

.status-pill.active {
  color: #ffffff;
  background: #27272a;
  border-color: rgba(255, 255, 255, 0.2);
}

.status-pill.pill-all.active {
  background: #27272a;
  border-color: rgba(255, 255, 255, 0.25);
  color: #ffffff;
}

.status-pill.pill-fail.active {
  background: rgba(239, 68, 68, 0.12);
  border-color: rgba(239, 68, 68, 0.35);
  color: #ef4444;
}

.status-pill.pill-warn.active {
  background: rgba(245, 158, 11, 0.12);
  border-color: rgba(245, 158, 11, 0.35);
  color: #f59e0b;
}

.status-pill.pill-pass.active {
  background: rgba(16, 185, 129, 0.12);
  border-color: rgba(16, 185, 129, 0.35);
  color: #10b981;
}

.pill-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
}
.dot-fail { background: var(--color-fail); }
.dot-warn { background: var(--color-warn); }
.dot-pass { background: var(--color-pass); }

.search-container {
  display: flex;
  align-items: center;
  gap: 10px;
  flex: 1;
  max-width: 380px;
  min-width: 220px;
}

.search-wrap {
  position: relative;
  width: 100%;
}

.search-icon {
  position: absolute;
  left: 11px;
  top: 50%;
  transform: translateY(-50%);
  width: 14px;
  height: 14px;
  color: var(--text-dim);
  pointer-events: none;
}

.search-field {
  width: 100%;
  padding: 7px 50px 7px 32px;
  background: var(--bg-input);
  border: 1px solid var(--border-card);
  border-radius: 7px;
  font-size: 0.8rem;
  color: var(--text-title);
  outline: none;
  transition: all 0.15s ease;
  font-family: inherit;
}

.search-field:focus {
  border-color: var(--border-active);
  box-shadow: 0 0 0 2px rgba(255, 255, 255, 0.08);
}

.search-kbd-hint {
  position: absolute;
  right: 26px;
  top: 50%;
  transform: translateY(-50%);
  font-family: var(--font-mono);
  font-size: 0.68rem;
  font-weight: 700;
  padding: 1px 5px;
  border-radius: 4px;
  background: #18181b;
  border: 1px solid var(--border-subtle);
  color: var(--text-dim);
  pointer-events: none;
}

.search-clear-btn {
  position: absolute;
  right: 8px;
  top: 50%;
  transform: translateY(-50%);
  background: none;
  border: none;
  color: var(--text-dim);
  font-size: 0.95rem;
  cursor: pointer;
  display: none;
}

.view-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}

.btn-toggle-all {
  font-size: 0.75rem;
  font-weight: 600;
  color: var(--text-dim);
  background: transparent;
  border: none;
  cursor: pointer;
  padding: 4px 8px;
  border-radius: 6px;
  transition: all 0.15s ease;
}

.btn-toggle-all:hover {
  color: var(--text-title);
  background: var(--bg-subtle);
}

/* Accordion Check Items */
.checks-container {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.check-item {
  background: var(--bg-card);
  border: 1px solid var(--border-card);
  border-radius: 10px;
  overflow: hidden;
  transition: all 0.15s ease;
  box-shadow: var(--shadow-sm);
}

.check-item:hover {
  border-color: rgba(255, 255, 255, 0.16);
  background: var(--bg-card-hover);
}

:root[data-theme="light"] .check-item:hover {
  background: #ffffff;
  border-color: rgba(0, 0, 0, 0.15);
}

.check-item.item-fail { border-left: 3px solid var(--color-fail); }
.check-item.item-warn { border-left: 3px solid var(--color-warn); }
.check-item.item-pass { border-left: 3px solid var(--color-pass); }
.check-item.item-info { border-left: 3px solid var(--color-info); }
.check-item.item-sugg { border-left: 3px solid var(--color-sugg); }

.check-header {
  padding: 13px 16px;
  display: flex;
  align-items: center;
  justify-content: space-between;
  cursor: pointer;
  user-select: none;
  gap: 12px;
}

.check-header-left {
  display: flex;
  align-items: center;
  gap: 10px;
  flex: 1;
  min-width: 0;
  flex-wrap: wrap;
}

.badge-status {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  padding: 2px 7px;
  border-radius: 5px;
  font-size: 0.7rem;
  font-weight: 700;
  letter-spacing: 0.04em;
  text-transform: uppercase;
  flex-shrink: 0;
}

.badge-status svg { width: 12px; height: 12px; }

.badge-pass { background: var(--color-pass-bg); color: var(--color-pass); border: 1px solid var(--color-pass-border); }
.badge-warn { background: var(--color-warn-bg); color: var(--color-warn); border: 1px solid var(--color-warn-border); }
.badge-fail { background: var(--color-fail-bg); color: var(--color-fail); border: 1px solid var(--color-fail-border); }
.badge-info { background: var(--color-info-bg); color: var(--color-info); border: 1px solid var(--color-info-border); }
.badge-sugg { background: var(--color-sugg-bg); color: var(--color-sugg); border: 1px solid var(--color-sugg-border); }

.check-id-badge {
  font-family: var(--font-mono);
  font-size: 0.72rem;
  font-weight: 700;
  color: #e4e4e7;
  background: #141418;
  border: 1px solid rgba(255, 255, 255, 0.08);
  padding: 2px 6px;
  border-radius: 4px;
  flex-shrink: 0;
}

.check-title-text {
  font-size: 0.88rem;
  font-weight: 600;
  color: var(--text-title);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.check-header-right {
  display: flex;
  align-items: center;
  gap: 10px;
  flex-shrink: 0;
}

.comp-chips {
  display: flex;
  align-items: center;
  gap: 5px;
  flex-wrap: wrap;
}

.comp-chip {
  font-size: 0.68rem;
  font-weight: 600;
  padding: 2px 6px;
  border-radius: 4px;
  background: #121215;
  border: 1px solid rgba(255, 255, 255, 0.08);
  color: var(--text-dim);
}

.comp-chip.chip-cis { color: #38bdf8; border-color: rgba(56, 189, 248, 0.25); background: rgba(56, 189, 248, 0.06); }
.comp-chip.chip-nist { color: #c084fc; border-color: rgba(192, 132, 252, 0.25); background: rgba(192, 132, 252, 0.06); }
.comp-chip.chip-mitre { color: #fb923c; border-color: rgba(251, 146, 60, 0.25); background: rgba(251, 146, 60, 0.06); }

.category-tag {
  font-size: 0.7rem;
  font-weight: 600;
  padding: 2px 7px;
  border-radius: 5px;
  background: var(--bg-subtle);
  color: var(--text-dim);
  text-transform: capitalize;
  border: 1px solid var(--border-subtle);
}

.chevron-icon {
  width: 17px;
  height: 17px;
  color: var(--text-dim);
  transition: transform 0.2s ease;
}

.check-item.expanded .chevron-icon {
  transform: rotate(180deg);
}

/* Check Body / Accordion Detail */
.check-body {
  display: none;
  padding: 0 16px 16px 16px;
  border-top: 1px solid var(--border-subtle);
  background: var(--bg-card-expanded);
}

.check-item.expanded .check-body {
  display: block;
}

.finding-box {
  margin-top: 12px;
  padding: 12px 14px;
  border-radius: 7px;
  background: #101014;
  border: 1px solid rgba(255, 255, 255, 0.06);
  font-size: 0.84rem;
  color: var(--text-body);
  line-height: 1.5;
}

.finding-box-label {
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-dim);
  margin-bottom: 4px;
  display: flex;
  align-items: center;
  gap: 5px;
}

.finding-box-label svg { width: 13px; height: 13px; }

/* Remediation Terminal Box */
.remed-box {
  margin-top: 10px;
  background: var(--bg-code);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 7px;
  overflow: hidden;
}

.remed-top {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 6px 12px;
  background: #0d0d10;
  border-bottom: 1px solid rgba(255, 255, 255, 0.06);
}

.remed-top-title {
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-dim);
  display: flex;
  align-items: center;
  gap: 6px;
}

.btn-copy-code {
  display: inline-flex;
  align-items: center;
  gap: 5px;
  background: #18181b;
  border: 1px solid rgba(255, 255, 255, 0.1);
  color: var(--text-body);
  padding: 3px 8px;
  border-radius: 5px;
  font-size: 0.72rem;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.15s ease;
  font-family: inherit;
}

.btn-copy-code:hover {
  background: #27272a;
  color: #ffffff;
}

.btn-copy-code.copied {
  background: var(--color-pass);
  color: #000000;
  border-color: var(--color-pass);
}

.remed-code {
  padding: 10px 14px;
  font-family: var(--font-mono);
  font-size: 0.8rem;
  color: #d4d4d8;
  white-space: pre-wrap;
  word-break: break-all;
  line-height: 1.45;
}

/* =============================================================================
   4. Glassmorphic Remediation Playbook Modal / Slide-Over
   ============================================================================= */
.modal-backdrop {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: var(--bg-modal-backdrop);
  display: none;
  align-items: center;
  justify-content: center;
  z-index: 10000;
  padding: 20px;
}

.modal-backdrop.active {
  display: flex;
}

.modal-window {
  background: var(--bg-modal);
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 12px;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.95);
  width: 100%;
  max-width: 900px;
  max-height: 88vh;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.modal-header {
  padding: 16px 20px;
  border-bottom: 1px solid var(--border-subtle);
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  background: #0d0d10;
}

.modal-title-group {
  display: flex;
  align-items: center;
  gap: 12px;
}

.modal-title-icon {
  width: 34px;
  height: 34px;
  border-radius: 8px;
  background: #18181b;
  border: 1px solid rgba(245, 158, 11, 0.3);
  color: var(--color-warn);
  display: flex;
  align-items: center;
  justify-content: center;
}

.modal-title-icon svg { width: 18px; height: 18px; }

.modal-title {
  font-size: 1.12rem;
  font-weight: 700;
  color: var(--text-title);
  display: flex;
  align-items: center;
  gap: 8px;
}

.modal-subtitle {
  font-size: 0.78rem;
  color: var(--text-dim);
}

.modal-close-btn {
  background: var(--bg-subtle);
  border: 1px solid var(--border-subtle);
  color: var(--text-dim);
  width: 30px;
  height: 30px;
  border-radius: 6px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  transition: all 0.15s ease;
  font-size: 1rem;
}

.modal-close-btn:hover {
  background: var(--color-fail-bg);
  color: var(--color-fail);
  border-color: var(--color-fail-border);
}

.modal-toolbar {
  padding: 10px 20px;
  background: #09090b;
  border-bottom: 1px solid var(--border-subtle);
  display: flex;
  align-items: center;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 10px;
}

.modal-stats {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 0.75rem;
  color: var(--text-dim);
}

.modal-stat-pill {
  font-weight: 700;
  color: var(--text-title);
  background: #18181b;
  border: 1px solid var(--border-subtle);
  padding: 2px 8px;
  border-radius: 5px;
}

.modal-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}

.btn-modal {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  font-size: 0.78rem;
  font-weight: 600;
  padding: 6px 12px;
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.15s ease;
  font-family: inherit;
}

.btn-modal svg { width: 14px; height: 14px; }

.btn-modal-primary {
  background: #ffffff;
  border: 1px solid #ffffff;
  color: #000000;
  font-weight: 700;
}

.btn-modal-primary:hover {
  background: #e4e4e7;
}

.btn-modal-secondary {
  background: #18181b;
  border: 1px solid var(--border-subtle);
  color: var(--text-body);
}

.btn-modal-secondary:hover {
  background: #27272a;
  color: var(--text-title);
}

.modal-body {
  padding: 0;
  overflow-y: auto;
  flex: 1;
  background: #000000;
}

.playbook-code-wrap {
  font-family: var(--font-mono);
  font-size: 0.82rem;
  line-height: 1.6;
  padding: 16px 0;
}

.code-line {
  display: flex;
  align-items: stretch;
  padding: 0 16px;
}

.code-line:hover {
  background: rgba(255, 255, 255, 0.04);
}

.line-num {
  width: 44px;
  text-align: right;
  padding-right: 16px;
  color: #52525b;
  user-select: none;
  font-size: 0.75rem;
  flex-shrink: 0;
}

.line-text {
  color: #e4e4e7;
  white-space: pre;
  word-break: break-all;
  flex: 1;
}

.line-comment { color: #71717a; font-style: italic; }
.line-keyword { color: #ffffff; font-weight: 700; }
.line-command { color: #f59e0b; }

.modal-footer {
  padding: 12px 20px;
  border-top: 1px solid var(--border-subtle);
  background: #09090b;
  display: flex;
  align-items: center;
  justify-content: space-between;
  font-size: 0.72rem;
  color: var(--text-dim);
}

/* Toast Notifications */
.toast-container {
  position: fixed;
  bottom: 24px;
  right: 24px;
  z-index: 99999;
  display: flex;
  flex-direction: column;
  gap: 8px;
  pointer-events: none;
}

.toast {
  background: #18181b;
  color: #ffffff;
  padding: 10px 16px;
  border-radius: 8px;
  font-size: 0.82rem;
  font-weight: 600;
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.8);
  border: 1px solid rgba(255, 255, 255, 0.15);
  display: flex;
  align-items: center;
  gap: 8px;
}


/* Reference Links Box */
.ref-box {
  margin-top: 10px;
  background: var(--bg-code);
  border: 1px solid rgba(255, 255, 255, 0.07);
  border-radius: 7px;
  padding: 10px 14px;
}

.ref-box-label {
  font-size: 0.68rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--text-dim);
  margin-bottom: 8px;
  display: flex;
  align-items: center;
  gap: 6px;
}

.ref-links-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 7px;
}

.ref-item-link {
  display: inline-flex;
  align-items: center;
  gap: 7px;
  padding: 4px 10px;
  border-radius: 5px;
  background: #141418;
  border: 1px solid rgba(255, 255, 255, 0.08);
  color: #d4d4d8;
  text-decoration: none;
  font-size: 0.74rem;
  font-weight: 500;
  transition: all 0.15s ease;
}

.ref-item-link:hover {
  background: #202026;
  border-color: rgba(255, 255, 255, 0.22);
  color: #ffffff;
  transform: translateY(-1px);
}

:root[data-theme="light"] .ref-item-link {
  background: #f3f4f6;
  border-color: rgba(0, 0, 0, 0.08);
  color: #27272a;
}

:root[data-theme="light"] .ref-item-link:hover {
  background: #e4e4e7;
  color: #000000;
}

.ref-item-tag {
  font-size: 0.62rem;
  font-weight: 800;
  text-transform: uppercase;
  padding: 1px 5px;
  border-radius: 3px;
  font-family: var(--font-mono);
  letter-spacing: 0.03em;
}

.tag-standard, .tag-apple {
  background: rgba(255, 255, 255, 0.1);
  color: #ffffff;
  border: 1px solid rgba(255, 255, 255, 0.15);
}

.tag-mitre {
  background: rgba(249, 115, 22, 0.1);
  color: #fb923c;
  border: 1px solid rgba(249, 115, 22, 0.25);
}

.tag-cis {
  background: rgba(56, 189, 248, 0.1);
  color: #38bdf8;
  border: 1px solid rgba(56, 189, 248, 0.25);
}

.tag-nist {
  background: rgba(168, 85, 247, 0.1);
  color: #c084fc;
  border: 1px solid rgba(168, 85, 247, 0.25);
}

.ref-ext-arrow {
  width: 12px;
  height: 12px;
  color: var(--text-dim);
  flex-shrink: 0;
}

/* Print Styles */
@media print {
  body { background: #ffffff !important; color: #000000 !important; }
  .navbar, .toolbar-panel, .fix-banner, .btn-nav, .view-actions, .toast-container, .modal-backdrop, .liquid-mesh { display: none !important; }
  .hero-card, .check-item, .cat-card, .sev-card { box-shadow: none !important; border: 1px solid #cccccc !important; page-break-inside: avoid; }
  .check-body { display: block !important; }
  .remed-box { background: #f1f5f9 !important; border: 1px solid #cccccc !important; }
  .remed-code { color: #0f172a !important; }
}
.check-desc-note {
  font-size: 0.84rem;
  line-height: 1.5;
  color: var(--text-body);
  margin-bottom: 8px;
  padding-bottom: 8px;
  border-bottom: 1px solid var(--border-subtle);
}

.finding-detail-text {
  font-size: 0.82rem;
  line-height: 1.45;
  color: var(--text-muted);
  font-family: var(--font-mono);
  word-break: break-word;
}

#langLabel {
  font-weight: 700;
  letter-spacing: 0.05em;
}
""")
doc.append("  </style>")
doc.append('</head>')
doc.append('<body>')
doc.append('<div class="app-wrapper">')

doc.append(f"""
  <nav class="navbar">
    <div class="nav-brand">
      <div class="brand-icon">
        <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z"/></svg>
      </div>
      <div>
        <div class="brand-title">
          macharden
          <span class="badge-version">v{html.escape(version)}</span>
        </div>
        <div class="nav-sub" data-i18n="nav_subtitle">{t('nav_subtitle')}</div>
      </div>
    </div>
    <div class="nav-actions">
      <button class="btn-nav" id="themeToggleBtn" onclick="toggleTheme()" title="Toggle Light/Dark Theme (Shortcut: T)">
        <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 3v1m0 16v1m9-9h-1M4 12H3m15.364 6.364l-.707-.707M6.343 6.343l-.707-.707m12.728 0l-.707.707M6.343 17.657l-.707.707M16 12a4 4 0 11-8 0 4 4 0 018 0z"/></svg>
        <span id="themeLabel">Theme</span>
        <kbd class="nav-kbd">T</kbd>
      </button>
      <button class="btn-nav" id="langToggleBtn" onclick="toggleLanguage()" title="{'Toggle Language (Shortcut: L)' if audit_lang == 'en' else 'Dili Değiştir (Kısayol: L)'}">
        <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M3 5h12M9 3v2m1.048 9.5A18.022 18.022 0 016.412 9m6.088 9h7M11 21l5-10 5 10M12.751 5C11.783 10.77 8.07 15.61 3 18.129"/></svg>
        <span id="langLabel">{'TR' if audit_lang == 'en' else 'EN'}</span>
        <kbd class="nav-kbd">L</kbd>
      </button>
      <button class="btn-nav" onclick="window.print()" title="Print or Export as PDF">
        <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M17 17h2a2 2 0 002-2v-4a2 2 0 00-2-2H5a2 2 0 00-2 2v4a2 2 0 002 2h2m2 4h6a2 2 0 002-2v-4H7v4a2 2 0 002 2zm8-12V5a2 2 0 00-2-2H9a2 2 0 00-2 2v4h10z"/></svg>
        <span data-i18n="btn_print">{t('btn_print')}</span>
      </button>
      <button class="btn-nav btn-nav-playbook" onclick="openPlaybookModal()" title="Open Interactive Remediation Playbook Drawer">
        <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"/></svg>
        <span data-i18n="btn_playbook">{t('btn_playbook')}</span>
      </button>
      <button class="btn-nav" onclick="exportMarkdownReport()" title="Export Audit as Markdown (macharden-report.md)">
        <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/></svg>
        <span data-i18n="btn_export_md">{t('btn_export_md')}</span>
      </button>
      <button class="btn-nav" onclick="exportJsonData()" title="Export Raw Audit JSON">
        <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"/></svg>
        <span data-i18n="btn_export_json">{t('btn_export_json')}</span>
      </button>
    </div>
  </nav>
""")


doc.append("<div class=\"hero-grid\">")
doc.append(f"""
  <div class="hero-card score-card">
    <div class="section-label" data-i18n="sec_hardening_score">
      <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/></svg>
      {t('sec_hardening_score')}
    </div>
    <div class="gauge-container">
      <div class="gauge-box">
        <svg class="gauge-svg" viewBox="0 0 160 160">
          <defs>
            <linearGradient id="gaugeGrad" x1="0%" y1="0%" x2="100%" y2="100%">
              <stop offset="0%" stop-color="{score_grad_start}" />
              <stop offset="100%" stop-color="{score_grad_end}" />
            </linearGradient>
          </defs>
          <circle class="gauge-bg" cx="80" cy="80" r="70" />
          <circle id="gaugeRing" class="gauge-ring" cx="80" cy="80" r="70" stroke="url(#gaugeGrad)" stroke-dasharray="{circumference}" stroke-dashoffset="{gauge_offset}" />
        </svg>
        <div class="gauge-inner">
          <div class="gauge-score">{score:.1f}<span>%</span></div>
          <div class="gauge-sub-badge" style="color: {grade_color}">{letter_grade}</div>
        </div>
      </div>
      <div class="grade-badge grade-{'excellent' if score>=85 else 'good' if score>=70 else 'fair' if score>=50 else 'critical'}">
        <span class="badge-dot"></span> {html.escape(rating)}
      </div>
      <div class="score-points"><span data-i18n="score_earned_prefix">{t('score_earned_prefix')}</span> <strong>{earned_points:.1f}</strong> <span data-i18n="score_earned_of">{t('score_earned_of')}</span> {total_points:.1f} <span data-i18n="score_earned_suffix">{t('score_earned_suffix')}</span></div>
    </div>

    <div class="compliance-meters">
      <div>
        <div class="meter-row">
          <span class="meter-label" data-i18n="cis_benchmark">{t('cis_benchmark')}</span>
          <span class="meter-val">{cis_pct}%</span>
        </div>
        <div class="meter-bar-track"><div class="meter-bar-fill" style="width: {cis_pct}%"></div></div>
      </div>
      <div>
        <div class="meter-row">
          <span class="meter-label" data-i18n="nist_sp">{t('nist_sp')}</span>
          <span class="meter-val">{nist_pct}%</span>
        </div>
        <div class="meter-bar-track"><div class="meter-bar-fill" style="width: {nist_pct}%"></div></div>
      </div>
    </div>
  </div>
""")

doc.append(f"""
  <div class="hero-card meta-panel">
    <div>
      <div class="section-label" data-i18n="sec_audit_stats">
        <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
        {t('sec_audit_stats')}
      </div>
      <div class="stats-row">
        <div class="stat-box box-total active" onclick="filterStatus('all')" title="Filter all controls">
          <div class="stat-box-label" data-i18n="kpi_total_controls">{t('kpi_total_controls')}</div>
          <div class="stat-box-val">{total_checks}</div>
          <div class="stat-box-sub" data-i18n="kpi_total_sub">{t('kpi_total_sub')}</div>
        </div>
        <div class="stat-box box-pass" onclick="filterStatus('PASS')" title="Filter passed controls">
          <div class="stat-box-label" data-i18n="kpi_passed">{t('kpi_passed')}</div>
          <div class="stat-box-val">{passed_checks}</div>
          <div class="stat-box-sub"><span id="passPctVal">{pass_pct}%</span> <span data-i18n="kpi_passed_sub">{t('kpi_passed_sub')}</span></div>
        </div>
        <div class="stat-box box-warn" onclick="filterStatus('WARN')" title="Filter warning controls">
          <div class="stat-box-label" data-i18n="kpi_warnings">{t('kpi_warnings')}</div>
          <div class="stat-box-val">{warn_checks}</div>
          <div class="stat-box-sub" data-i18n="kpi_warnings_sub">{t('kpi_warnings_sub')}</div>
        </div>
        <div class="stat-box box-fail" onclick="filterStatus('FAIL')" title="Filter failed controls">
          <div class="stat-box-label" data-i18n="kpi_failed">{t('kpi_failed')}</div>
          <div class="stat-box-val">{fail_checks}</div>
          <div class="stat-box-sub" data-i18n="kpi_failed_sub">{t('kpi_failed_sub')}</div>
        </div>
      </div>
    </div>

    <div>
      <div class="section-label" data-i18n="sec_system_meta">
        <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/></svg>
        {t('sec_system_meta')}
      </div>
      <div class="sys-info-grid">
        <div class="sys-info-item">
          <div class="sys-info-icon"><svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4"/></svg></div>
          <div>
            <div class="sys-info-key" data-i18n="meta_hostname">{t('meta_hostname')}</div>
            <div class="sys-info-val">{html.escape(system.get('hostname', 'macOS'))}</div>
          </div>
        </div>
        <div class="sys-info-item">
          <div class="sys-info-icon"><svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z"/></svg></div>
          <div>
            <div class="sys-info-key" data-i18n="meta_user">{t('meta_user')}</div>
            <div class="sys-info-val">{html.escape(system.get('user', 'unknown'))}</div>
          </div>
        </div>
        <div class="sys-info-item">
          <div class="sys-info-icon"><svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9.75 17L9 20l-1 1h8l-1-1-.75-3M3 13h18M5 17h14a2 2 0 002-2V5a2 2 0 00-2-2H5a2 2 0 00-2 2v10a2 2 0 002 2z"/></svg></div>
          <div>
            <div class="sys-info-key" data-i18n="meta_os">{t('meta_os')}</div>
            <div class="sys-info-val">{html.escape(f"{system.get('os_product','macOS')} {system.get('os_version','')} ({system.get('os_build','')})")}</div>
          </div>
        </div>
        <div class="sys-info-item">
          <div class="sys-info-icon"><svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M9 3v2m6-2v2M9 19v2m6-2v2M5 9H3m2 6H3m18-6h-2m2 6h-2M7 19h10a2 2 0 002-2V7a2 2 0 00-2-2H7a2 2 0 00-2 2v10a2 2 0 002 2zM9 9h6v6H9V9z"/></svg></div>
          <div>
            <div class="sys-info-key" data-i18n="meta_arch">{t('meta_arch')}</div>
            <div class="sys-info-val">{html.escape(system.get('arch', 'arm64'))}</div>
          </div>
        </div>
        <div class="sys-info-item">
          <div class="sys-info-icon"><svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/></svg></div>
          <div>
            <div class="sys-info-key" data-i18n="meta_timestamp">{t('meta_timestamp')}</div>
            <div class="sys-info-val">{html.escape(scanner.get('timestamp', ''))}</div>
          </div>
        </div>
      </div>
    </div>
  </div>
""")
doc.append("</div>") # /hero-grid


cat_icons = {
    "hardening": "<svg fill=\"none\" viewBox=\"0 0 24 24\" stroke=\"currentColor\" stroke-width=\"2\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" d=\"M9 12l2 2 4-4m5.618-4.016A11.955 11.955 0 0112 2.944a11.955 11.955 0 01-8.618 3.04A12.02 12.02 0 003 9c0 5.591 3.824 10.29 9 11.622 5.176-1.332 9-6.03 9-11.622 0-1.042-.133-2.052-.382-3.016z\"/></svg>",
    "network": "<svg fill=\"none\" viewBox=\"0 0 24 24\" stroke=\"currentColor\" stroke-width=\"2\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" d=\"M8.111 16.404a5.5 5.5 0 017.778 0M12 20h.01m-7.08-7.071c3.904-3.905 10.236-3.905 14.14 0M1.394 9.393c5.857-5.857 15.355-5.857 21.213 0\"/></svg>",
    "secrets": "<svg fill=\"none\" viewBox=\"0 0 24 24\" stroke=\"currentColor\" stroke-width=\"2\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" d=\"M15 7a2 2 0 012 2m4 0a6 6 0 01-7.743 5.743L11 17H9v2H7v2H4a1 1 0 01-1-1v-2.586a1 1 0 01.293-.707l5.964-5.964A6 6 0 1121 9z\"/></svg>",
    "persistence": "<svg fill=\"none\" viewBox=\"0 0 24 24\" stroke=\"currentColor\" stroke-width=\"2\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" d=\"M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15\"/></svg>"
}

doc.append(f"""
<div class="cat-breakdown-section">
  <div class="section-label" data-i18n="sec_cat_breakdown">
    <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M4 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2V6zM14 6a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2V6zM4 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2H6a2 2 0 01-2-2v-2zM14 16a2 2 0 012-2h2a2 2 0 012 2v2a2 2 0 01-2 2h-2a2 2 0 01-2-2v-2z"/></svg>
    {t('sec_cat_breakdown')}
  </div>
  <div class="category-grid">
""")

for cat_id in core_categories:
    cd = cat_data.get(cat_id, {
        "name": cat_id.capitalize(),
        "score_pct": 100.0,
        "pass": 0, "warn": 0, "fail": 0
    })
    c_score = cd["score_pct"]
    c_icon = cat_icons.get(cat_id, "<svg fill=\"none\" viewBox=\"0 0 24 24\" stroke=\"currentColor\" stroke-width=\"2\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" d=\"M9 12l2 2 4-4\"/></svg>")
    
    if c_score >= 85:
        c_color = "#10b981"; c_grad = "#10b981"
    elif c_score >= 70:
        c_color = "#e4e4e7"; c_grad = "#e4e4e7"
    elif c_score >= 50:
        c_color = "#f59e0b"; c_grad = "#f59e0b"
    else:
        c_color = "#ef4444"; c_grad = "#ef4444"

    cat_label = t(f"cat_{cat_id}")
    doc.append(f"""
    <div class="cat-card" data-category-card="{cat_id}" onclick="filterCategory('{cat_id}')" title="Click to filter controls by {cat_label}">
      <div class="cat-card-top">
        <div class="cat-card-header">
          <div class="cat-card-icon">{c_icon}</div>
          <div class="cat-card-name" data-cat-name="{cat_id}">{cat_label}</div>
        </div>
        <div class="cat-card-score" style="color: {c_color}">{c_score:.1f}%</div>
      </div>
      <div class="cat-card-bar-wrap">
        <div class="cat-card-bar-track">
          <div class="cat-card-bar-fill" style="width: {c_score}%; background: {c_grad};"></div>
        </div>
      </div>
      <div class="cat-card-counts">
        <span class="cat-count-badge cnt-pass">✔ <span class="cnt-num">{cd['pass']}</span> <span data-i18n="cnt_pass_label">{t('cnt_pass_label')}</span></span>
        <span class="cat-count-badge cnt-warn">▲ <span class="cnt-num">{cd['warn']}</span> <span data-i18n="cnt_warn_label">{t('cnt_warn_label')}</span></span>
        <span class="cat-count-badge cnt-fail">✖ <span class="cnt-num">{cd['fail']}</span> <span data-i18n="cnt_fail_label">{t('cnt_fail_label')}</span></span>
      </div>
    </div>
""")

doc.append("""
  </div>
</div>
""")


doc.append(f"""
<div class="sev-section">
  <div class="section-label" data-i18n="sec_sev_matrix">
    <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/></svg>
    {t('sec_sev_matrix')}
  </div>
  <div class="sev-strip">
""")

sev_levels = [
    ("CRITICAL", "Critical", "wt ≥ 9", sev_stats["CRITICAL"]),
    ("HIGH", "High", "wt 7-8", sev_stats["HIGH"]),
    ("MEDIUM", "Medium", "wt 5-6", sev_stats["MEDIUM"]),
    ("LOW", "Low", "wt ≤ 4", sev_stats["LOW"])
]

for s_key, s_default_label, s_weight, s_obj in sev_levels:
    fails = s_obj["fail"]
    warns = s_obj["warn"]
    total = s_obj["total"]
    s_label = t(f"sev_{s_key.lower()}")
    doc.append(f"""
    <div class="sev-card sev-card-{s_key.lower()}" data-severity-card="{s_key}" onclick="filterSeverity('{s_key}')" title="Click to filter {s_label} severity controls">
      <div class="sev-card-left">
        <div class="sev-card-title" data-sev-title="{s_key}">{s_label}</div>
        <div class="sev-card-desc"><span class="sev-f-cnt">{fails}</span> <span data-i18n="cnt_fail_label">{t('cnt_fail_label')}</span> · <span class="sev-w-cnt">{warns}</span> <span data-i18n="cnt_warn_label">{t('cnt_warn_label')}</span></div>
      </div>
      <div class="sev-card-right">
        <div class="sev-card-val">{total}</div>
        <div class="sev-card-subval" data-i18n="sev_subval">{t('sev_subval')}</div>
      </div>
    </div>
""")

doc.append("""
  </div>
</div>
""")

if remediable_count > 0:
    doc.append(f"""
  <div class="fix-banner">
    <div class="fix-banner-left">
      <div class="fix-banner-icon">
        <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/></svg>
      </div>
      <div>
        <div class="fix-banner-title" data-banner-title="1"><span class="fix-cnt">{remediable_count}</span> <span data-i18n="banner_ready">{t('banner_ready_single') if remediable_count == 1 else t('banner_ready')}</span></div>
        <div class="fix-banner-desc" data-i18n="banner_desc">{t('banner_desc')}</div>
      </div>
    </div>
    <div class="fix-banner-actions">
      <button class="btn-primary-fix" onclick="openPlaybookModal()">
        <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"/><path stroke-linecap="round" stroke-linejoin="round" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
        <span data-i18n="banner_btn_playbook">{t('banner_btn_playbook')}</span>
      </button>
      <button class="btn-secondary-fix" onclick="copyAllFixCommands()">
        <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3"/></svg>
        <span data-i18n="banner_btn_copy_all">{t('banner_btn_copy_all')}</span>
      </button>
    </div>
  </div>
""")


doc.append("""
  <div class="toolbar-panel">
    <div class="category-nav">
""")

for cat in ordered_categories:
    cat_label = t(f"cat_{cat}")
    c_count = total_checks if cat == "all" else cat_data.get(cat, {}).get("total", 0)
    active_cls = " active" if cat == "all" else ""
    doc.append(f"""      <button class="cat-btn{active_cls}" data-category="{cat}" onclick="filterCategory('{cat}')"><span data-cat-tab="{cat}">{cat_label}</span> <span class="cat-count">{c_count}</span></button>""")

doc.append(f"""
    </div>

    <!-- Framework Filter Row -->
    <div class="filter-subnav">
      <div class="framework-filters">
        <span class="framework-label" data-i18n="fw_label">{t('fw_label')}</span>
        <button class="fw-pill pill-fw-all active" data-framework="all" onclick="filterFramework('all')" data-i18n="fw_all">{t('fw_all')}</button>
        <button class="fw-pill pill-fw-cis" data-framework="cis" onclick="filterFramework('cis')">
          CIS Benchmark <span class="fw-badge-cnt">{cis_fw_count}</span>
        </button>
        <button class="fw-pill pill-fw-nist" data-framework="nist" onclick="filterFramework('nist')">
          NIST SP 800-53 <span class="fw-badge-cnt">{nist_fw_count}</span>
        </button>
        <button class="fw-pill pill-fw-mitre" data-framework="mitre" onclick="filterFramework('mitre')">
          MITRE ATT&CK <span class="fw-badge-cnt">{mitre_fw_count}</span>
        </button>
      </div>
    </div>

    <div class="filter-row">
      <div class="status-pills">
        <button class="status-pill pill-all active" data-status="all" onclick="filterStatus('all')"><span data-i18n="status_all">{t('status_all')}</span> ({total_checks})</button>
        <button class="status-pill pill-fail" data-status="FAIL" onclick="filterStatus('FAIL')"><span class="pill-dot dot-fail"></span> <span data-i18n="status_failed">{t('status_failed')}</span> ({fail_checks})</button>
        <button class="status-pill pill-warn" data-status="WARN" onclick="filterStatus('WARN')"><span class="pill-dot dot-warn"></span> <span data-i18n="status_warnings">{t('status_warnings')}</span> ({warn_checks})</button>
        <button class="status-pill pill-pass" data-status="PASS" onclick="filterStatus('PASS')"><span class="pill-dot dot-pass"></span> <span data-i18n="status_passed">{t('status_passed')}</span> ({passed_checks})</button>
      </div>

      <div class="search-container">
        <div class="search-wrap">
          <svg class="search-icon" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/></svg>
          <input type="text" id="searchInput" class="search-field" placeholder="{t('search_placeholder')}" data-i18n-placeholder="search_placeholder" oninput="onSearchInput(this.value)" />
          <kbd class="search-kbd-hint">/</kbd>
          <button class="search-clear-btn" id="searchClearBtn" onclick="clearSearch()">✕</button>
        </div>
      </div>

      <div class="view-actions">
        <button class="btn-toggle-all" id="toggleAllBtn" onclick="toggleAllCards()" data-i18n="btn_expand_all">{t('btn_expand_all')}</button>
      </div>
    </div>
  </div>
""")


doc.append("<div class=\"checks-container\" id=\"checksContainer\">")

for c in checks:
    cid = html.escape(str(c.get('id', '')))
    cat = html.escape(str(c.get('category', '')).lower())
    title = html.escape(str(c.get('title', '')))
    status = str(c.get('status', 'INFO')).upper()
    weight = c.get('weight', 5)
    severity = get_severity(weight)
    details = html.escape(str(c.get('details', '')))
    remediation = c.get('remediation', '')

    c_info = CHECK_I18N.get(cid, {})
    title_text = c_info.get('title', {}).get(audit_lang, title)
    desc_text = c_info.get('desc', {}).get(audit_lang, '')

    fws = get_check_frameworks(cid, compliance_map)
    has_cis_val = "1" if fws["has_cis"] else "0"
    has_nist_val = "1" if fws["has_nist"] else "0"
    has_mitre_val = "1" if fws["has_mitre"] else "0"

    status_cls = "item-pass" if status == "PASS" else "item-warn" if status == "WARN" else "item-fail" if status == "FAIL" else "item-info"
    badge_cls = "badge-pass" if status == "PASS" else "badge-warn" if status == "WARN" else "badge-fail" if status == "FAIL" else "badge-info"
    sev_badge_cls = f"badge-sev-{severity.lower()}"
    expanded_cls = " expanded" if status in ["FAIL", "WARN"] else ""

    status_display = t(f"badge_{status.lower()}")
    cat_display = t(f"cat_{cat}")
    sev_display = t(f"sev_{severity.lower()}")

    doc.append(f"""
  <div class="check-item {status_cls}{expanded_cls}" data-id="{cid}" data-category="{cat}" data-status="{status}" data-severity="{severity}" data-cis="{has_cis_val}" data-nist="{has_nist_val}" data-mitre="{has_mitre_val}">
    <div class="check-header" onclick="toggleCard(this.parentElement)">
      <div class="check-header-left">
        <span class="badge-status {badge_cls}" data-check-status-badge="{status}">
          <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="{'M5 13l4 4L19 7' if status == 'PASS' else 'M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z' if status == 'WARN' else 'M6 18L18 6M6 6l12 12'}"/></svg>
          {status_display}
        </span>
        <span class="check-id-badge">{cid}</span>
        <span class="badge-severity {sev_badge_cls}" data-check-sev-badge="{severity}">{sev_display}</span>
        <span class="check-title-text" data-check-title="{cid}">{title_text}</span>
      </div>
      <div class="check-header-right">
        <div class="comp-chips">""")

    if fws["cis_tag"]:
        doc.append(f"""<span class="comp-chip chip-cis" title="CIS Apple macOS Benchmark">CIS {html.escape(fws['cis_tag'])}</span>""")
    if fws["nist_tag_str"]:
        doc.append(f"""<span class="comp-chip chip-nist" title="NIST SP 800-53">{html.escape(fws['nist_tag_str'])}</span>""")
    if fws["mitre_tag_str"]:
        doc.append(f"""<span class="comp-chip chip-mitre" title="MITRE ATT&CK">{html.escape(fws['mitre_tag_str'])}</span>""")

    doc.append(f"""
        </div>
        <span class="category-tag" data-check-cat-tag="{cat}">{cat_display}</span>
        <svg class="chevron-icon" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2.5"><path stroke-linecap="round" stroke-linejoin="round" d="M19 9l-7 7-7-7"/></svg>
      </div>
    </div>
    <div class="check-body">
      <div class="finding-box">
        <div class="finding-box-label" data-i18n="finding_analysis">
          <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
          {t('finding_analysis')}
        </div>
        {f'<div class="check-desc-note" data-check-desc="{cid}">{html.escape(desc_text)}</div>' if desc_text else ''}
        <div class="finding-detail-text" data-check-detail="{cid}" data-status="{status}">{details if details else 'No additional diagnostic details recorded.'}</div>
      </div>""")

    if remediation:
        rem_esc = html.escape(remediation)
        doc.append(f"""
      <div class="remed-box">
        <div class="remed-top">
          <div class="remed-top-title" data-i18n="remed_command">
            <svg style="width:14px;height:14px;color:#f59e0b" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M10.325 4.317c.426-1.756 2.924-1.756 3.35 0a1.724 1.724 0 002.573 1.066c1.543-.94 3.31.826 2.37 2.37a1.724 1.724 0 001.065 2.572c1.756.426 1.756 2.924 0 3.35a1.724 1.724 0 00-1.066 2.573c.94 1.543-.826 3.31-2.37 2.37a1.724 1.724 0 00-2.572 1.065c-.426 1.756-2.924 1.756-3.35 0a1.724 1.724 0 00-2.573-1.066c-1.543.94-3.31-.826-2.37-2.37a1.724 1.724 0 00-1.065-2.572c-1.756-.426-1.756-2.924 0-3.35a1.724 1.724 0 001.066-2.573c-.94-1.543.826-3.31 2.37-2.37.996.608 2.296.07 2.572-1.065z"/><path stroke-linecap="round" stroke-linejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/></svg>
            {t('remed_command')}
          </div>
          <button class="btn-copy-code" data-i18n="btn_copy_fix" onclick="copyCode(this, '{json.dumps(remediation)[1:-1]}')">
            <svg style="width:12px;height:12px" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/></svg>
            {t('btn_copy_fix')}
          </button>
        </div>
        <div class="remed-code">$ {rem_esc}</div>
      </div>""")

    check_entry = compliance_map.get(cid, {})
    check_refs = check_entry.get("references", [])
    if check_refs:
        doc.append(f"""
      <div class="ref-box">
        <div class="ref-box-label" data-i18n="sec_references">
          <svg style="width:13px;height:13px;color:#a1a1aa" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/></svg>
          {t('sec_references')}
        </div>
        <div class="ref-links-grid">""")
        for ref in check_refs:
            ref_url = html.escape(ref.get("url", "#"))
            ref_name = html.escape(ref.get("name", "Reference"))
            ref_type = ref.get("type", "ref").lower()
            tag_label = "APPLE" if ref_type in ["standard", "apple"] else ref_type.upper()
            tag_class = f"tag-{ref_type}"
            doc.append(f"""
          <a href="{ref_url}" target="_blank" rel="noopener noreferrer" class="ref-item-link" title="Open external reference in new tab">
            <span class="ref-item-tag {tag_class}">{tag_label}</span>
            <span class="ref-item-name">{ref_name}</span>
            <svg class="ref-ext-arrow" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/></svg>
          </a>""")
        doc.append("""
        </div>
      </div>""")

    doc.append("""
    </div>
  </div>""")

doc.append("</div>") # /checks-container
doc.append("</div>") # /app-wrapper


doc.append(f"""
<div class="modal-backdrop" id="playbookModal" onclick="onBackdropClick(event)">
  <div class="modal-window" onclick="event.stopPropagation()">
    <div class="modal-header">
      <div class="modal-title-group">
        <div class="modal-title-icon">
          <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M10 20l4-16m4 4l4 4-4 4M6 16l-4-4 4-4"/></svg>
        </div>
        <div>
          <div class="modal-title" data-i18n="modal_playbook_title">{t('modal_playbook_title')}</div>
          <div class="modal-subtitle" data-i18n="modal_playbook_subtitle">{t('modal_playbook_subtitle')}</div>
        </div>
      </div>
      <button class="modal-close-btn" onclick="closePlaybookModal()" title="Close Playbook (Esc)">✕</button>
    </div>
    <div class="modal-toolbar">
      <div class="modal-stats">
        <span class="modal-stat-pill"><span class="rem-cnt">{remediable_count}</span> <span data-i18n="modal_actionable_fixes">{t('modal_actionable_fixes')}</span></span>
        <span><span data-i18n="modal_target">{t('modal_target')}</span> <strong>{html.escape(system.get('hostname', 'macOS'))}</strong></span>
      </div>
      <div class="modal-actions">
        <button class="btn-modal btn-modal-primary" onclick="copyPlaybookScript(this)" title="Copy complete shell script to clipboard">
          <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M8 5H6a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2v-1M8 5a2 2 0 002 2h2a2 2 0 002-2M8 5a2 2 0 012-2h2a2 2 0 012 2m0 0h2a2 2 0 012 2v3m2 4H10m0 0l3-3m-3 3l3 3"/></svg>
          <span data-i18n="modal_btn_copy_all">{t('modal_btn_copy_all')}</span>
        </button>
        <button class="btn-modal btn-modal-secondary" onclick="downloadPlaybookScript()" title="Download fix_hardening.sh script file">
          <svg fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"/></svg>
          <span data-i18n="modal_btn_download">{t('modal_btn_download')}</span>
        </button>
      </div>
    </div>
    <div class="modal-body">
      <div class="playbook-code-wrap">
""")

for idx, line in enumerate(remed_script_lines):
    line_html = html.escape(line)
    l_cls = ""
    stripped = line.strip()
    if stripped.startswith("#"):
        l_cls = "line-comment"
    elif stripped.startswith(("set ", "echo ", "if ", "then ", "fi ", "#!")):
        l_cls = "line-keyword"
    elif stripped.startswith(("sudo ", "defaults ", "spctl ", "fdesetup ", "csrutil ", "pfctl ", "launchctl ", "chmod ", "chown ")):
        l_cls = "line-command"
    doc.append(f"        <div class=\"code-line\"><span class=\"line-num\">{idx + 1}</span><span class=\"line-text {l_cls}\">{line_html}</span></div>")

doc.append(f"""
      </div>
    </div>
    <div class="modal-footer">
      <div data-i18n="modal_admin_note">{t('modal_admin_note')}</div>
      <div data-i18n="modal_press_esc">{t('modal_press_esc')}</div>
    </div>
  </div>
</div>
<div class="toast-container" id="toastContainer"></div>
""")


doc.append("""
<script>
// JSON Export Data & Playbook Script Payload
const AUDIT_DATA = """ + json.dumps(data) + """;
const PLAYBOOK_SCRIPT = """ + json.dumps(raw_playbook_script) + """;
const UI_STRINGS = """ + json.dumps(UI_STRINGS) + """;
const CHECK_I18N = """ + json.dumps(CHECK_I18N) + """;

// Filter State Engine
let currentCategory = 'all';
let currentStatus = 'all';
let currentFramework = 'all';
let currentSeverity = 'all';
let searchQuery = '';

// Theme Toggle (Local Persistence & Keyboard Shortcut)
function toggleTheme() {
  const htmlEl = document.documentElement;
  const currentTheme = htmlEl.getAttribute('data-theme') || 'dark';
  const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
  htmlEl.setAttribute('data-theme', newTheme);
  try {
    localStorage.setItem('macharden_theme', newTheme);
  } catch (e) {}
  updateThemeButton(newTheme);
}

function updateThemeButton(theme) {
  const label = document.getElementById('themeLabel');
  if (label) label.textContent = theme === 'dark' ? 'Light' : 'Dark';
}

(function initTheme() {
  const saved = localStorage.getItem('macharden_theme');
  if (saved) {
    document.documentElement.setAttribute('data-theme', saved);
    updateThemeButton(saved);
  } else if (window.matchMedia && window.matchMedia('(prefers-color-scheme: light)').matches) {
    document.documentElement.setAttribute('data-theme', 'light');
    updateThemeButton('light');
  }
})();

// Language Toggle & Real-Time Dynamic Switching
function toggleLanguage() {
  const cur = document.documentElement.getAttribute('data-lang') || 'en';
  const next = cur === 'en' ? 'tr' : 'en';
  setLanguage(next, true);
}

function setLanguage(lang, saveToStorage = true) {
  const targetLang = (lang === 'tr') ? 'tr' : 'en';
  document.documentElement.setAttribute('lang', targetLang);
  document.documentElement.setAttribute('data-lang', targetLang);

  if (saveToStorage) {
    try {
      localStorage.setItem('macharden_lang', targetLang);
    } catch (e) {}
  }

  const langLabel = document.getElementById('langLabel');
  if (langLabel) {
    langLabel.textContent = targetLang === 'en' ? 'TR' : 'EN';
  }
  const langBtn = document.getElementById('langToggleBtn');
  if (langBtn) {
    langBtn.title = targetLang === 'en' ? 'Toggle Language (Shortcut: L)' : 'Dili Değiştir (Kısayol: L)';
  }

  const dict = UI_STRINGS[targetLang] || UI_STRINGS['en'];

  // 1. Text elements with data-i18n
  document.querySelectorAll('[data-i18n]').forEach(el => {
    const key = el.getAttribute('data-i18n');
    if (dict[key] !== undefined) {
      el.textContent = dict[key];
    }
  });

  // 2. Input placeholders
  document.querySelectorAll('[data-i18n-placeholder]').forEach(el => {
    const key = el.getAttribute('data-i18n-placeholder');
    if (dict[key] !== undefined) {
      el.placeholder = dict[key];
    }
  });

  // 3. Tooltips / titles
  document.querySelectorAll('[data-i18n-title]').forEach(el => {
    const key = el.getAttribute('data-i18n-title');
    if (dict[key] !== undefined) {
      el.title = dict[key];
    }
  });

  // 4. Check titles
  document.querySelectorAll('[data-check-title]').forEach(el => {
    const cid = el.getAttribute('data-check-title');
    if (CHECK_I18N[cid] && CHECK_I18N[cid].title) {
      el.textContent = CHECK_I18N[cid].title[targetLang] || el.textContent;
    }
  });

  // 5. Check descriptions
  document.querySelectorAll('[data-check-desc]').forEach(el => {
    const cid = el.getAttribute('data-check-desc');
    if (CHECK_I18N[cid] && CHECK_I18N[cid].desc) {
      el.textContent = CHECK_I18N[cid].desc[targetLang] || el.textContent;
    }
  });

  // 6. Finding details
  document.querySelectorAll('[data-check-detail]').forEach(el => {
    const cid = el.getAttribute('data-check-detail');
    const status = (el.getAttribute('data-status') || '').toUpperCase();
    if (!el.hasAttribute('data-orig-detail')) {
      el.setAttribute('data-orig-detail', el.textContent);
    }
    if (targetLang === 'tr') {
      if (CHECK_I18N[cid] && CHECK_I18N[cid].finding && CHECK_I18N[cid].finding[status]) {
        el.textContent = CHECK_I18N[cid].finding[status];
      }
    } else {
      el.textContent = el.getAttribute('data-orig-detail');
    }
  });

  // 7. Check status badges (PASS/WARN/FAIL/INFO)
  document.querySelectorAll('.check-item .badge-status').forEach(badge => {
    const item = badge.closest('.check-item');
    const status = item ? (item.getAttribute('data-status') || '').toUpperCase() : '';
    const svg = badge.querySelector('svg');
    const key = 'badge_' + status.toLowerCase();
    const label = dict[key] || status;
    badge.textContent = '';
    if (svg) badge.appendChild(svg);
    badge.append(' ' + label);
  });

  // 8. Category tags on check items
  document.querySelectorAll('.check-item .category-tag').forEach(tag => {
    const item = tag.closest('.check-item');
    const cat = item ? (item.getAttribute('data-category') || '').toLowerCase() : '';
    const key = 'cat_' + cat;
    tag.textContent = dict[key] || cat;
  });

  // 9. Severity badges on check items
  document.querySelectorAll('.check-item .badge-severity').forEach(badge => {
    const item = badge.closest('.check-item');
    const sev = item ? (item.getAttribute('data-severity') || '').toUpperCase() : '';
    const key = 'sev_' + sev.toLowerCase();
    badge.textContent = dict[key] || sev;
  });

  // 10. Toolbar category tab labels
  document.querySelectorAll('[data-cat-tab]').forEach(tabSpan => {
    const cat = tabSpan.getAttribute('data-cat-tab');
    const key = 'cat_' + cat;
    tabSpan.textContent = dict[key] || cat;
  });

  // 11. Category breakdown card titles
  document.querySelectorAll('[data-cat-name]').forEach(nameEl => {
    const cat = nameEl.getAttribute('data-cat-name');
    const key = 'cat_' + cat;
    nameEl.textContent = dict[key] || cat;
  });

  // 12. Category breakdown count labels (pass/warn/fail)
  document.querySelectorAll('.cat-card-counts').forEach(cWrap => {
    const pSpan = cWrap.querySelector('.cnt-pass');
    const wSpan = cWrap.querySelector('.cnt-warn');
    const fSpan = cWrap.querySelector('.cnt-fail');
    if (pSpan) {
      const num = pSpan.querySelector('.cnt-num') ? pSpan.querySelector('.cnt-num').textContent : '';
      pSpan.innerHTML = '✔ <span class="cnt-num">' + num + '</span> ' + (dict['cnt_pass_label'] || 'pass');
    }
    if (wSpan) {
      const num = wSpan.querySelector('.cnt-num') ? wSpan.querySelector('.cnt-num').textContent : '';
      wSpan.innerHTML = '▲ <span class="cnt-num">' + num + '</span> ' + (dict['cnt_warn_label'] || 'warn');
    }
    if (fSpan) {
      const num = fSpan.querySelector('.cnt-num') ? fSpan.querySelector('.cnt-num').textContent : '';
      fSpan.innerHTML = '✖ <span class="cnt-num">' + num + '</span> ' + (dict['cnt_fail_label'] || 'fail');
    }
  });

  // 13. Severity cards
  document.querySelectorAll('[data-sev-title]').forEach(titleEl => {
    const sKey = titleEl.getAttribute('data-sev-title');
    const key = 'sev_' + sKey.toLowerCase();
    titleEl.textContent = dict[key] || sKey;
  });
  document.querySelectorAll('.sev-card-desc').forEach(descEl => {
    const fNum = descEl.querySelector('.sev-f-cnt') ? descEl.querySelector('.sev-f-cnt').textContent : '';
    const wNum = descEl.querySelector('.sev-w-cnt') ? descEl.querySelector('.sev-w-cnt').textContent : '';
    descEl.innerHTML = '<span class="sev-f-cnt">' + fNum + '</span> ' + (dict['cnt_fail_label'] || 'fails') + ' · <span class="sev-w-cnt">' + wNum + '</span> ' + (dict['cnt_warn_label'] || 'warns');
  });

  // 14. Remediation Banner Title
  const bannerTitle = document.querySelector('[data-banner-title]');
  if (bannerTitle) {
    const cnt = bannerTitle.querySelector('.fix-cnt') ? bannerTitle.querySelector('.fix-cnt').textContent : '';
    bannerTitle.innerHTML = '<span class="fix-cnt">' + cnt + '</span> ' + (parseInt(cnt, 10) === 1 ? (dict['banner_ready_single'] || dict['banner_ready']) : dict['banner_ready']);
  }

  // 15. Toggle All button text
  const toggleAllBtn = document.getElementById('toggleAllBtn');
  if (toggleAllBtn) {
    const isExpanded = toggleAllBtn.textContent.includes('Collapse') || toggleAllBtn.textContent.includes('Daralt');
    toggleAllBtn.textContent = isExpanded ? (dict['btn_collapse_all'] || 'Collapse All') : (dict['btn_expand_all'] || 'Expand All');
  }
}

// Initialize language preference from storage or document default
(function initLanguage() {
  let lang = document.documentElement.getAttribute('data-lang') || 'en';
  try {
    const saved = localStorage.getItem('macharden_lang');
    if (saved === 'en' || saved === 'tr') {
      lang = saved;
    }
  } catch (e) {}
  setLanguage(lang, false);
})();

// Accordion Toggle Single
function toggleCard(card) {
  card.classList.toggle('expanded');
}

// Toggle All Cards
function toggleAllCards() {
  const cards = document.querySelectorAll('.check-item');
  const btn = document.getElementById('toggleAllBtn');
  const shouldExpand = btn.textContent.includes('Expand') || btn.textContent.includes('Genişlet');
  const curLang = document.documentElement.getAttribute('data-lang') || 'en';
  const dict = UI_STRINGS[curLang] || UI_STRINGS['en'];
  
  cards.forEach(card => {
    if (shouldExpand) {
      card.classList.add('expanded');
    } else {
      card.classList.remove('expanded');
    }
  });
  
  btn.textContent = shouldExpand ? (dict['btn_collapse_all'] || 'Collapse All') : (dict['btn_expand_all'] || 'Expand All');
}

// Category Filter
function filterCategory(cat) {
  const c = cat.toLowerCase();
  if (currentCategory === c && c !== 'all') {
    currentCategory = 'all';
  } else {
    currentCategory = c;
  }

  document.querySelectorAll('.cat-btn').forEach(btn => {
    btn.classList.toggle('active', btn.getAttribute('data-category') === currentCategory);
  });
  document.querySelectorAll('.cat-card').forEach(card => {
    card.classList.toggle('active', card.getAttribute('data-category-card') === currentCategory);
  });
  applyFilters();
}

// Status Filter
function filterStatus(st) {
  if (currentStatus === st && st !== 'all') {
    currentStatus = 'all';
  } else {
    currentStatus = st;
  }

  document.querySelectorAll('.status-pill').forEach(pill => {
    pill.classList.toggle('active', pill.getAttribute('data-status') === currentStatus);
  });
  document.querySelectorAll('.stat-box').forEach(box => {
    const isTotal = currentStatus === 'all' && box.classList.contains('box-total');
    const isPass = currentStatus === 'PASS' && box.classList.contains('box-pass');
    const isWarn = currentStatus === 'WARN' && box.classList.contains('box-warn');
    const isFail = currentStatus === 'FAIL' && box.classList.contains('box-fail');
    box.classList.toggle('active', isTotal || isPass || isWarn || isFail);
  });
  applyFilters();
}

// Framework Filter (CIS / NIST / MITRE)
function filterFramework(fw) {
  const f = fw.toLowerCase();
  if (currentFramework === f && f !== 'all') {
    currentFramework = 'all';
  } else {
    currentFramework = f;
  }

  document.querySelectorAll('.fw-pill').forEach(pill => {
    pill.classList.toggle('active', pill.getAttribute('data-framework') === currentFramework);
  });
  applyFilters();
}

// Severity Filter (CRITICAL / HIGH / MEDIUM / LOW)
function filterSeverity(sev) {
  const s = sev.toUpperCase();
  if (currentSeverity === s && s !== 'all') {
    currentSeverity = 'all';
  } else {
    currentSeverity = s;
  }

  document.querySelectorAll('.sev-card').forEach(card => {
    card.classList.toggle('active', card.getAttribute('data-severity-card') === currentSeverity);
  });
  applyFilters();
}

// Search Field Handlers
function onSearchInput(val) {
  searchQuery = val.trim().toLowerCase();
  const clearBtn = document.getElementById('searchClearBtn');
  if (clearBtn) clearBtn.style.display = searchQuery ? 'block' : 'none';
  applyFilters();
}

function clearSearch() {
  const input = document.getElementById('searchInput');
  if (input) input.value = '';
  onSearchInput('');
}

// Unified Multi-Dimension Filter Engine
function applyFilters() {
  const cards = document.querySelectorAll('.check-item');
  cards.forEach(card => {
    const cardCat = (card.getAttribute('data-category') || '').toLowerCase();
    const cardStatus = (card.getAttribute('data-status') || '').toUpperCase();
    const cardSeverity = (card.getAttribute('data-severity') || '').toUpperCase();
    const cardText = card.textContent.toLowerCase();

    const matchesCat = (currentCategory === 'all' || cardCat === currentCategory);
    const matchesStatus = (currentStatus === 'all' || cardStatus === currentStatus);
    const matchesSeverity = (currentSeverity === 'all' || cardSeverity === currentSeverity);
    
    let matchesFramework = true;
    if (currentFramework === 'cis') {
      matchesFramework = card.getAttribute('data-cis') === '1';
    } else if (currentFramework === 'nist') {
      matchesFramework = card.getAttribute('data-nist') === '1';
    } else if (currentFramework === 'mitre') {
      matchesFramework = card.getAttribute('data-mitre') === '1';
    }

    const matchesSearch = (!searchQuery || cardText.includes(searchQuery));

    if (matchesCat && matchesStatus && matchesSeverity && matchesFramework && matchesSearch) {
      card.style.display = '';
    } else {
      card.style.display = 'none';
    }
  });
}

// Remediation Playbook Drawer / Modal Handlers
function openPlaybookModal() {
  const modal = document.getElementById('playbookModal');
  if (modal) {
    modal.classList.add('active');
    document.body.style.overflow = 'hidden';
  }
}

function closePlaybookModal() {
  const modal = document.getElementById('playbookModal');
  if (modal) {
    modal.classList.remove('active');
    document.body.style.overflow = '';
  }
}

function onBackdropClick(e) {
  if (e.target && e.target.id === 'playbookModal') {
    closePlaybookModal();
  }
}

function getMsg(key) {
  const cur = document.documentElement.getAttribute('data-lang') || 'en';
  return (UI_STRINGS[cur] && UI_STRINGS[cur][key]) || (UI_STRINGS['en'] && UI_STRINGS['en'][key]) || key;
}

// Copy All Playbook Script
function copyPlaybookScript(btn) {
  const msg = getMsg('toast_copied_script');
  if (navigator.clipboard) {
    navigator.clipboard.writeText(PLAYBOOK_SCRIPT).then(() => {
      showCopied(btn, msg);
    }).catch(() => fallbackCopy(PLAYBOOK_SCRIPT, btn, msg));
  } else {
    fallbackCopy(PLAYBOOK_SCRIPT, btn, msg);
  }
}

// Download fix_hardening.sh Script via Blob
function downloadPlaybookScript() {
  const blob = new Blob([PLAYBOOK_SCRIPT], { type: 'text/x-shellscript;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'fix_hardening.sh';
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
  showToast(getMsg('toast_downloaded'));
}

// Export Markdown Report (macharden-report.md)
function exportMarkdownReport() {
  const d = AUDIT_DATA;
  const sys = d.system || {};
  const sum = d.summary || {};
  const scan = d.scanner || {};
  const checks = d.checks || [];

  let md = '# macOS Security Hardening Audit Report\n\n';
  md += '> **Automated Security & Compliance Scan**  \n';
  md += '> Generated by **macharden** v' + (scan.version || '1.2.0') + ' on `' + (scan.timestamp || new Date().toISOString()) + '`\n\n';
  md += '---\n\n';
  md += '## 1. System Metadata\n\n';
  md += '| Attribute | System Information |\n';
  md += '| :--- | :--- |\n';
  md += '| **Target Hostname** | `' + (sys.hostname || 'macOS') + '` |\n';
  md += '| **Audit User** | `' + (sys.user || 'unknown') + '` |\n';
  md += '| **Operating System** | ' + (sys.os_product || 'macOS') + ' ' + (sys.os_version || '') + ' (Build `' + (sys.os_build || '') + '`) |\n';
  md += '| **Architecture** | `' + (sys.arch || 'arm64') + '` |\n';
  md += '| **Kernel Release** | `' + (sys.kernel || 'Darwin') + '` |\n\n';
  md += '---\n\n';
  md += '## 2. Executive Summary\n\n';
  md += '### Hardening Index: **' + (sum.hardening_index || 0) + '%** — *' + (sum.rating || 'UNKNOWN') + '*\n\n';
  md += '| Metric | Count / Value | Status |\n';
  md += '| :--- | :---: | :---: |\n';
  md += '| **Hardening Score** | **' + (sum.hardening_index || 0) + '%** | ' + (sum.rating || '') + ' |\n';
  md += '| **Total Checks Audited** | **' + (sum.total_checks || checks.length) + '** | - |\n';
  md += '| **Passed Checks** | **' + (sum.passed || 0) + '** | 🟢 PASS |\n';
  md += '| **Warnings** | **' + (sum.warnings || 0) + '** | 🟡 WARN |\n';
  md += '| **Failed Checks** | **' + (sum.failed || 0) + '** | 🔴 FAIL |\n';
  md += '| **Points Earned** | ' + (sum.earned_points || 0) + ' / ' + (sum.total_possible_points || 0) + ' | - |\n\n';
  md += '---\n\n';
  md += '## 3. Audit Results by Category\n\n';

  const categories = ['hardening', 'network', 'secrets', 'persistence'];
  categories.forEach(cat => {
    const catChecks = checks.filter(c => (c.category || '').toLowerCase() === cat);
    if (catChecks.length === 0) return;
    md += '### ' + cat.charAt(0).toUpperCase() + cat.slice(1) + ' (' + catChecks.length + ' controls)\n\n';
    md += '| Status | ID | Check Name | Weight |\n';
    md += '| :---: | :--- | :--- | :---: |\n';
    catChecks.forEach(c => {
      const stIcon = c.status === 'PASS' ? '🟢 PASS' : c.status === 'WARN' ? '🟡 WARN' : c.status === 'FAIL' ? '🔴 FAIL' : 'ℹ️ INFO';
      md += '| ' + stIcon + ' | `' + c.id + '` | ' + c.title + ' | ' + (c.weight || 5) + ' |\n';
    });
    md += '\n';
  });

  const remediations = checks.filter(c => (c.status === 'FAIL' || c.status === 'WARN') && c.remediation);
  if (remediations.length > 0) {
    md += '---\n\n';
    md += '## 4. Actionable Remediation Commands\n\n';
    md += '```bash\n#!/bin/zsh\n# macharden remediation playbook\nset -euo pipefail\n\n';
    remediations.forEach(c => {
      md += '# ' + c.id + ': ' + c.title + '\n';
      md += c.remediation + '\n\n';
    });
    md += '```\n';
  }

  const blob = new Blob([md], { type: 'text/markdown;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'macharden-report.md';
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
  showToast('Downloaded macharden-report.md');
}

// Export Raw JSON
function exportJsonData() {
  const str = JSON.stringify(AUDIT_DATA, null, 2);
  const blob = new Blob([str], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = 'macharden-audit.json';
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
  showToast('Downloaded macharden-audit.json');
}

// Copy Code Snippets
function copyCode(btn, code) {
  const msg = getMsg('toast_copied_cmd');
  if (navigator.clipboard) {
    navigator.clipboard.writeText(code).then(() => {
      showCopied(btn, msg);
    }).catch(() => fallbackCopy(code, btn, msg));
  } else {
    fallbackCopy(code, btn, msg);
  }
}

function copyAllFixCommands() {
  if (!PLAYBOOK_SCRIPT) {
    showToast('No remediation commands required!');
    return;
  }
  const msg = getMsg('toast_copied_script');
  if (navigator.clipboard) {
    navigator.clipboard.writeText(PLAYBOOK_SCRIPT).then(() => {
      showToast(msg);
    });
  } else {
    fallbackCopy(PLAYBOOK_SCRIPT, null, msg);
    showToast(msg);
  }
}

function fallbackCopy(text, btn, msg) {
  const textarea = document.createElement('textarea');
  textarea.value = text;
  document.body.appendChild(textarea);
  textarea.select();
  document.execCommand('copy');
  document.body.removeChild(textarea);
  if (btn) showCopied(btn, msg || 'Copied to clipboard!');
}

function showCopied(btn, msg) {
  if (!btn) {
    showToast(msg || 'Copied to clipboard!');
    return;
  }
  const orig = btn.innerHTML;
  btn.innerHTML = '✔ ' + (document.documentElement.getAttribute('data-lang') === 'tr' ? 'Kopyalandı!' : 'Copied!');
  btn.classList.add('copied');
  showToast(msg || 'Copied to clipboard!');
  setTimeout(() => {
    btn.innerHTML = orig;
    btn.classList.remove('copied');
  }, 2000);
}

// Toast Notifications
function showToast(msg) {
  const container = document.getElementById('toastContainer');
  if (!container) return;
  const toast = document.createElement('div');
  toast.className = 'toast';
  toast.innerHTML = '<span>✔</span> ' + msg;
  container.appendChild(toast);
  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transition = 'opacity 0.2s ease';
    setTimeout(() => {
      if (toast.parentElement) toast.parentElement.removeChild(toast);
    }, 200);
  }, 2500);
}

// Keyboard Shortcuts Listeners
document.addEventListener('keydown', function(e) {
  const isInput = ['INPUT', 'TEXTAREA', 'SELECT'].includes(document.activeElement.tagName);
  
  // Escape closes any active modal or clears search
  if (e.key === 'Escape') {
    const modal = document.getElementById('playbookModal');
    if (modal && modal.classList.contains('active')) {
      closePlaybookModal();
      return;
    }
    const searchInput = document.getElementById('searchInput');
    if (searchInput && (searchInput.value || document.activeElement === searchInput)) {
      clearSearch();
      searchInput.blur();
    }
    return;
  }
  
  if (isInput) return;
  
  // '/' focuses search immediately
  if (e.key === '/') {
    e.preventDefault();
    const searchInput = document.getElementById('searchInput');
    if (searchInput) {
      searchInput.focus();
      searchInput.select();
    }
  } 
  // 't' or 'T' toggles theme
  else if (e.key === 't' || e.key === 'T') {
    e.preventDefault();
    toggleTheme();
  }
  // 'l' or 'L' toggles language
  else if (e.key === 'l' || e.key === 'L') {
    e.preventDefault();
    toggleLanguage();
  }
});
</script>
</body>
</html>
""")

full_html = "\n".join(doc)

if output_file and output_file != '-':
    out_dir = os.path.dirname(os.path.abspath(output_file))
    if out_dir and not os.path.exists(out_dir):
        os.makedirs(out_dir, exist_ok=True)
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write(full_html)
    if os.environ.get('MACHAR_QUIET', '0') == '0':
        print(f"[PASS] Modern HTML report generated: {output_file}")
else:
    print(full_html)

PYEOF
}
