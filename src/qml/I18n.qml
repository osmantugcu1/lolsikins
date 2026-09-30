pragma Singleton
import QtQuick 2.15

// UI strings in English, Turkish and Kurdish (Kurmanji). t() re-evaluates bindings when language changes.
QtObject {
    property int language: 0

    readonly property var languages: [ "English", "Türkçe", "Kurdî (Kurmancî)" ]

    // Game locales that ship their own voice-over, with their names in each interface language.
    readonly property var voiceLanguages: [
        { "code": "ja_JP", "names": [ "Japanese", "Japonca", "Japonî" ] },
        { "code": "ko_KR", "names": [ "Korean", "Korece", "Koreyî" ] },
        { "code": "zh_CN", "names": [ "Chinese (China)", "Çince (Çin)", "Çînî (Çîn)" ] },
        { "code": "zh_TW", "names": [ "Chinese (Taiwan)", "Çince (Tayvan)", "Çînî (Taywan)" ] },
        { "code": "en_US", "names": [ "English", "İngilizce", "Îngilîzî" ] },
        { "code": "es_ES", "names": [ "Spanish (Spain)", "İspanyolca (İspanya)", "Spanî (Spanya)" ] },
        { "code": "es_MX", "names": [ "Spanish (Latin America)", "İspanyolca (Latin Amerika)", "Spanî (Amerîkaya Latîn)" ] },
        { "code": "fr_FR", "names": [ "French", "Fransızca", "Fransî" ] },
        { "code": "de_DE", "names": [ "German", "Almanca", "Almanî" ] },
        { "code": "it_IT", "names": [ "Italian", "İtalyanca", "Îtalî" ] },
        { "code": "pt_BR", "names": [ "Portuguese (Brazil)", "Portekizce (Brezilya)", "Portugalî (Brezîlya)" ] },
        { "code": "ru_RU", "names": [ "Russian", "Rusça", "Rûsî" ] },
        { "code": "pl_PL", "names": [ "Polish", "Lehçe", "Polonî" ] },
        { "code": "tr_TR", "names": [ "Turkish", "Türkçe", "Tirkî" ] },
        { "code": "cs_CZ", "names": [ "Czech", "Çekçe", "Çekî" ] },
        { "code": "el_GR", "names": [ "Greek", "Yunanca", "Yûnanî" ] },
        { "code": "hu_HU", "names": [ "Hungarian", "Macarca", "Macarî" ] },
        { "code": "ro_RO", "names": [ "Romanian", "Rumence", "Romanî" ] },
        { "code": "ar_AE", "names": [ "Arabic", "Arapça", "Erebî" ] },
        { "code": "th_TH", "names": [ "Thai", "Tayca", "Tayî" ] },
        { "code": "vi_VN", "names": [ "Vietnamese", "Vietnamca", "Viyetnamî" ] }
    ]

    function voiceName(entry) {
        return entry.names[language] || entry.names[0]
    }

    readonly property var strings: ({
        // Header
        "skinsActive": [ "● Skins are active, you can join a game", "● Skinler aktif, oyuna girebilirsin", "● Skin çalak in, tu dikarî bikevî lîstikê" ],
        "modSummary": [ "%1 skins · %2 enabled", "%1 skin · %2 açık", "%1 skin · %2 vekirî" ],
        "store": [ "STORE", "MAĞAZA", "DIKAN" ],
        "settings": [ "Settings", "Ayarlar", "Mîheng" ],
        "start": [ "START", "BAŞLAT", "DEST PÊ BIKE" ],
        "stop": [ "STOP", "DURDUR", "RAWESTÎNE" ],
        "startTip": [ "Apply enabled skins to the game", "Açık skinleri oyuna uygula", "Skinên vekirî li lîstikê bicîh bîne" ],
        "stopTip": [ "Turn skins off", "Skinleri kapat", "Skinan bigire" ],

        "noSkinEnabled": [ "Turn on at least one skin first.", "Önce en az bir skini aç.", "Pêşî herî kêm skinekî veke." ],

        // Status bar
        "stWaiting": [ "Waiting for a match to start...", "Maçın başlaması bekleniyor...", "Li benda destpêka maçê..." ],
        "stFound": [ "Game found, applying skins...", "Oyun bulundu, skinler uygulanıyor...", "Lîstik hat dîtin, skin tên bicîhkirin..." ],
        "stActive": [ "Skins applied, have fun!", "Skinler oyuna uygulandı, iyi oyunlar!", "Skin hatin bicîhkirin, kêfxweş bilîze!" ],
        "stExited": [ "Game closed, waiting for the next one...", "Oyun kapandı, sıradaki bekleniyor...", "Lîstik hat girtin, li benda ya din..." ],
        "stPreparing": [ "Preparing skins...", "Skinler hazırlanıyor...", "Skin tên amadekirin..." ],
        "stInstalling": [ "Installing skin...", "Skin kuruluyor...", "Skin tê sazkirin..." ],
        "stUpdating": [ "Updating skin...", "Skin güncelleniyor...", "Skin tê nûkirin..." ],
        "stDeleting": [ "Removing skin...", "Skin siliniyor...", "Skin tê jêbirin..." ],
        "stLoading": [ "Loading...", "Yükleniyor...", "Tê barkirin..." ],
        "stTooLate": [ "The match had already loaded, skins will apply from the next one. Press START before the match loads.", "Maç zaten yüklenmişti, skinler bir sonraki maçta gelecek. BAŞLAT'a maç yüklenmeden bas.", "Maç jixwe hatibû barkirin, skin dê ji maça din dest pê bikin. Berî ku maç bar bibe DEST PÊ BIKE bitikîne." ],
        "stStopping": [ "Stopping...", "Durduruluyor...", "Tê rawestandin..." ],

        // Error dialog
        "errorTitle": [ "Error", "Hata", "Çewtî" ],
        "details": [ "DETAILS", "AYRINTILAR", "HÛRGULÎ" ],
        "copyDetails": [ "COPY DETAILS", "AYRINTILARI KOPYALA", "HÛRGULÎYAN KOPÎ BIKE" ],
        "closeUpper": [ "CLOSE", "KAPAT", "BIGIRE" ],

        // Mods
        "dropHere": [ "Drop the .fantome file to install it", "Kurmak için .fantome dosyasını bırak", "Ji bo sazkirinê pelê .fantome berde" ],
        "emptyTitle": [ "No skins yet", "Henüz skin yok", "Hêj skin tune ne" ],
        "emptyHint": [ "Get one from the store or drop a .fantome file here", "Mağazadan indir ya da buraya bir .fantome dosyası sürükle", "Ji dikanê daxe an pelekî .fantome bikişîne vir" ],
        "openStore": [ "OPEN STORE", "MAĞAZAYI AÇ", "DIKANÊ VEKE" ],
        "enableMod": [ "Turn this skin on or off", "Bu skini aç/kapat", "Vî skinî veke/bigire" ],
        "removeMod": [ "Remove this skin", "Bu skini sil", "Vî skinî jê bibe" ],
        "enableVoice": [ "Use this voice language (turns the other voice languages off)", "Bu ses dilini kullan (diğer ses dillerini kapatır)", "Vî zimanê deng bi kar bîne (zimanên deng ên din digire)" ],
        "removeVoice": [ "Delete this voice pack", "Bu ses paketini sil", "Vê pakêta deng jê bibe" ],
        "search": [ "Search...", "Ara...", "Bigere..." ],
        "enableAll": [ "ENABLE ALL", "HEPSİNİ AÇ", "HEMÛYAN VEKE" ],
        "disableAll": [ "DISABLE ALL", "HEPSİNİ KAPAT", "HEMÛYAN BIGIRE" ],
        "importFile": [ "Install from a .fantome file", "Dosyadan kur (.fantome)", "Ji pelê saz bike (.fantome)" ],
        "refresh": [ "Refresh", "Yenile", "Nû bike" ],

        // Settings
        "settingsTitle": [ "Settings", "Ayarlar", "Mîheng" ],
        "sectionGame": [ "GAME", "OYUN", "LÎSTIK" ],
        "sectionApp": [ "APP", "UYGULAMA", "SEPAN" ],
        "sectionVoice": [ "VOICE LANGUAGE", "SES DİLİ", "ZIMANÊ DENG" ],
        "voiceLanguage": [ "Voice language", "Ses dili", "Zimanê deng" ],
        "voiceDownload": [ "DOWNLOAD", "İNDİR", "DAXE" ],
        "voiceHint": [ "Every language you download becomes its own card in your mod list (about 4 GB each, from Riot's servers). Turn on the one you want: only one voice language can be on at a time, and with all of them off you hear the game's own voices. Only the voices change, text stays in the game's language. Update a language after big patches, and avoid downloading during a match.", "İndirdiğin her dil mod listende ayrı bir kart olur (her biri yaklaşık 4 GB, Riot'un sunucularından). İstediğini aç: aynı anda tek bir ses dili açık olabilir, hepsi kapalıyken oyunun kendi seslerini duyarsın. Sadece sesler değişir, yazılar oyunun dilinde kalır. Büyük yamalardan sonra dili güncelle, maç sırasında indirmemeye çalış.", "Her zimanê ku tu daxî di lîsteya modan de dibe kartek cuda (her yek nêzî 4 GB, ji serverên Riot). Yê ku tu dixwazî veke: di heman demê de tenê zimanekî deng dikare vekirî be, dema hemû girtî bin tu dengên lîstikê yên xwe dibihîzî. Tenê deng diguherin, nivîs bi zimanê lîstikê dimînin. Piştî nûkirinên mezin zimên nû bike, di dema maçê de daxistinê neke." ],
        "voicePreparing": [ "Reading the game and Riot's file list…", "Oyun ve Riot'un dosya listesi okunuyor…", "Lîstik û lîsteya pelên Riot tê xwendin…" ],
        "voiceProgress": [ "Downloading: %1 / %2 MB (%3 / %4 files)", "İndiriliyor: %1 / %2 MB (%3 / %4 dosya)", "Tê daxistin: %1 / %2 MB (%3 / %4 pel)" ],
        "voiceDone": [ "Voice pack ready and turned on. Press START to play with it.", "Ses paketi hazır ve açıldı. Kullanmak için BAŞLAT'a bas.", "Pakêta deng amade ye û vekirî ye. Ji bo bikaranînê DEST PÊ BIKE bitikîne." ],
        "voiceCanceled": [ "Canceled. Downloading again continues where it stopped.", "İptal edildi. Tekrar indirirsen kaldığı yerden devam eder.", "Hat betalkirin. Ger dîsa daxî, ji cihê ku lê sekinî berdewam dike." ],
        "voiceFailed": [ "Voice pack failed: %1", "Ses paketi oluşturulamadı: %1", "Pakêta deng nehat çêkirin: %1" ],
        "voiceNeedGame": [ "Pick the game folder first.", "Önce oyun klasörünü seç.", "Pêşî peldanka lîstikê hilbijêre." ],
        "voiceSame": [ "The game already speaks this language.", "Oyun zaten bu dilde konuşuyor.", "Lîstik jixwe bi vî zimanî diaxive." ],
        "voiceModName": [ "Voice: %1", "Ses: %1", "Deng: %1" ],
        "sectionHelp": [ "HELP", "YARDIM", "ALÎKARÎ" ],
        "gameFolder": [ "Game folder", "Oyun klasörü", "Peldanka lîstikê" ],
        "gameFolderNone": [ "Not selected", "Seçilmedi", "Nehatiye hilbijartin" ],
        "change": [ "CHANGE", "DEĞİŞTİR", "BIGUHERE" ],
        "detectGame": [ "Find the game folder automatically", "Oyun klasörünü otomatik bul", "Peldanka lîstikê bixweber bibîne" ],
        "blacklist": [ "Skip TFT and other game mode files", "TFT ve diğer mod dosyalarını atla", "Pelên TFT û modên din derbas bike" ],
        "suppressConflicts": [ "Ignore conflicts between skins", "Skinler arası çakışmaları yok say", "Pevçûnên navbera skinan paşguh bike" ],
        "ignoreBad": [ "Skip broken .wad files", "Bozuk .wad dosyalarını atla", "Pelên .wad ên xerab derbas bike" ],
        "skinhackScan": [ "Anti-skinhack scan (may lower FPS)", "Anti-skinhack taraması (FPS düşürebilir)", "Kontrola dij-skinhackê (dibe ku FPS kêm bike)" ],
        "language": [ "Language", "Dil", "Ziman" ],
        "theme": [ "Neon theme", "Neon teması", "Tema neon" ],
        "themeCyber": [ "Cyber (cyan / pink)", "Siber (camgöbeği / pembe)", "Sîber (şînê vekirî / pembe)" ],
        "themeGalaxy": [ "Galaxy (purple / pink)", "Galaksi (mor / pembe)", "Galaksî (mor / pembe)" ],
        "themeToxic": [ "Toxic (green / cyan)", "Toksik (yeşil / camgöbeği)", "Jehrî (kesk / şînê vekirî)" ],
        "themeLava": [ "Lava (orange / red)", "Lav (turuncu / kırmızı)", "Lava (porteqalî / sor)" ],
        "systray": [ "Keep running in the system tray", "Sistem tepsisinde çalışmaya devam et", "Di tepsiya pergalê de bixebite" ],
        "autoRun": [ "Start skins when the app opens", "Program açılınca skinleri başlat", "Dema sepan vebe skinan dest pê bike" ],
        "verbose": [ "Detailed logging", "Ayrıntılı kayıt", "Qeyda berfireh" ],
        "logs": [ "LOG FILE", "LOG DOSYASI", "PELÊ QEYDÊ" ],
        "diag": [ "TROUBLESHOOT", "SORUN GİDER", "PIRSGIRÊKAN ÇARESER BIKE" ],
        "close": [ "Close", "Kapat", "Bigire" ],

        // Tray
        "trayShow": [ "Show", "Göster", "Nîşan bide" ],
        "trayHide": [ "Minimize", "Küçült", "Biçûk bike" ],
        "trayExit": [ "Exit", "Çıkış", "Derkeve" ],

        // Store
        "storeTitle": [ "Skin Store", "Skin Mağazası", "Dikana Skinan" ],
        "repoPlaceholder": [ "Repository (user/repo)", "Repo (kullanıcı/repo)", "Depo (bikarhêner/depo)" ],
        "tokenPlaceholder": [ "GitHub token (for private repos)", "GitHub token (gizli repo için)", "Tokena GitHub (ji bo depoyên taybet)" ],
        "connect": [ "CONNECT", "BAĞLAN", "GIRÊ BIDE" ],
        "allChampions": [ "All champions", "Tüm şampiyonlar", "Hemû şampiyon" ],
        "chromas": [ "Chromas", "Chromalar", "Chroma" ],
        "autoUpdate": [ "Auto update", "Otomatik güncelle", "Nûkirina xweber" ],
        "scanning": [ "Scanning the repository...", "Repo taranıyor...", "Depo tê kolandin..." ],
        "noFantome": [ "No .fantome files in this repository.", "Repoda .fantome dosyası bulunamadı.", "Di vê depoyê de pelê .fantome tune." ],
        "skinsFound": [ "%1 skins found.", "%1 skin bulundu.", "%1 skin hatin dîtin." ],
        "truncated": [ "The repository is too big, GitHub cut part of the list.", "Repo çok büyük, GitHub listenin bir kısmını kesti.", "Depo pir mezin e, GitHub beşek ji lîsteyê birî." ],
        "downloading": [ "Downloading: %1 (%2)", "İndiriliyor: %1 (%2)", "Tê daxistin: %1 (%2)" ],
        "downloadedWaiting": [ "Downloaded, waiting: %1", "İndirildi, sıra bekleniyor: %1", "Hat daxistin, li benda rêzê ye: %1" ],
        "installing": [ "Installing: %1", "Kuruluyor: %1", "Tê sazkirin: %1" ],
        "updating": [ "Updating: %1", "Güncelleniyor: %1", "Tê nûkirin: %1" ],
        "installedDone": [ "Installed: %1", "Kuruldu: %1", "Hat sazkirin: %1" ],
        "updatedDone": [ "Updated: %1", "Güncellendi: %1", "Hat nûkirin: %1" ],
        "failedDone": [ "Could not finish: %1", "İşlem tamamlanamadı: %1", "Nehat temamkirin: %1" ],
        "needGame": [ "Pick the game folder before installing skins.", "Oyun klasörü seçilmeden skin kurulamaz.", "Berî sazkirina skinan peldanka lîstikê hilbijêre." ],
        "updateDownloading": [ "Downloading update: %1", "Güncelleme indiriliyor: %1", "Nûkirin tê daxistin: %1" ],
        "working": [ "WORKING...", "ÇALIŞIYOR...", "DIXEBITE..." ],
        "update": [ "UPDATE", "GÜNCELLE", "NÛ BIKE" ],
        "isInstalled": [ "INSTALLED", "KURULU", "SAZKIRÎ" ],
        "install": [ "INSTALL", "İNDİR VE KUR", "DAXE Û SAZ BIKE" ],
        "storeEmpty": [ "Enter your skin repository above and press CONNECT. Every .fantome file in it will show up here.", "Yukarıya skin reponu yazıp BAĞLAN'a bas. Repodaki bütün .fantome dosyaları burada listelenir.", "Depoya skinên xwe li jor binivîse û GIRÊ BIDE bitikîne. Hemû pelên .fantome yên di wê de dê li vir xuya bibin." ],
        "storeNoMatch": [ "No skins match the filter.", "Filtreye uyan skin yok.", "Tu skin li gorî parzûnê tune ne." ],
        "cancel": [ "CANCEL", "İPTAL", "BETAL BIKE" ],

        // Errors from the store backend
        "errRepoFormat": [ "The repository must look like \"user/repo\".", "Repo adresi \"kullanıcı/repo\" şeklinde olmalı.", "Divê depo wek \"bikarhêner/depo\" be." ],
        "errToken": [ "The GitHub token is invalid or expired.", "GitHub token geçersiz ya da süresi dolmuş.", "Tokena GitHub nederbasdar e an dema wê qediyaye." ],
        "errForbidden": [ "GitHub refused the request (no access or rate limit). Add a token and try again.", "GitHub isteği reddetti (yetki yok ya da istek limiti doldu). Token girip tekrar dene.", "GitHub daxwaz red kir (destûr tune an sînor qediya). Tokenekê binivîse û dîsa biceribîne." ],
        "errNotFound": [ "Repository, branch or file not found. Private repositories need a token.", "Repo, branch ya da dosya bulunamadı. Repo gizliyse token girmen gerekiyor.", "Depo, şax an pel nehat dîtin. Ji bo depoya taybet token pêwîst e." ],
        "errHttp": [ "GitHub returned an error (HTTP %1): %2", "GitHub hata döndürdü (HTTP %1): %2", "GitHub çewtiyek şand (HTTP %1): %2" ],
        "errNetwork": [ "Connection error: %1", "Bağlantı hatası: %1", "Çewtiya girêdanê: %1" ],
        "errTempFile": [ "Could not open a temporary file: %1", "Geçici dosya açılamadı: %1", "Pelê demkî venebû: %1" ],
        "errCanceled": [ "Download canceled.", "İndirme iptal edildi.", "Daxistin hat betalkirin." ],

        // Errors from the patcher
        "errPatcherMissing": [ "The patcher was not found (the patcher folder is missing). Extract the whole LolSikins zip again. If it disappears again, your antivirus removed it.", "Patcher bulunamadı (patcher klasörü eksik). LolSikins zip'ini baştan, eksiksiz çıkar. Yine kaybolursa antivirüs silmiş demektir.", "Patcher nehat dîtin (peldanka patcher tune ye). Zip'a LolSikins dîsa bi tevahî veke. Ger dîsa winda bibe, antîvîrusê ew jê biriye." ],
        "errPatcherExited": [ "The patcher closed unexpectedly, antivirus may have blocked it. %1", "Patcher beklenmedik şekilde kapandı, antivirüs engellemiş olabilir. %1", "Patcher bi awayekî nehêvî hat girtin, dibe ku antîvîrusê asteng kiribe. %1" ],
        "errPatcherFailed": [ "The patcher could not attach to the game: %1", "Patcher oyuna bağlanamadı: %1", "Patcher nikarî bi lîstikê ve girê bide: %1" ],
        "errPatcherScan": [ "A skin failed the anti-skinhack scan, so skins were stopped: %1", "Bir skin anti-skinhack taramasından geçemedi, skinler durduruldu: %1", "Skinek di kontrola dij-skinhackê de derbas nebû, skin hatin rawestandin: %1" ],
        "errPatcherEol": [ "The patcher reached its end of life, a new LolSikins version is needed. (Repository owner: GitHub → Actions → Build Windows → Run workflow.)", "Patcher'ın süresi doldu, LolSikins'in yeni sürümü lazım. (Repo sahibi: GitHub → Actions → Build Windows → Run workflow.)", "Dema patcher qediya, guhertoyeke nû ya LolSikins pêwîst e. (Xwediyê depoyê: GitHub → Actions → Build Windows → Run workflow.)" ],
        "errPatcherOverlay": [ "The game rejected the skins: %1", "Oyun skinleri reddetti: %1", "Lîstikê skin red kirin: %1" ],
        "errPatcherHook": [ "The patcher could not hook the game (%1).", "Patcher oyuna kanca atamadı (%1).", "Patcher nikarî xwe bi lîstikê ve girê bide (%1)." ]
    })

    // Backend and patcher status lines that have a translation.
    readonly property var statusKeys: ({
        "Waiting for league match to start": "stWaiting",
        "Found League": "stFound",
        "Wait initialized": "stFound",
        "Scanning": "stFound",
        "Saving": "stFound",
        "Wait patchable": "stFound",
        "Patching": "stFound",
        "Waiting for exit": "stActive",
        "League exited": "stExited",
        "Joined too late": "stTooLate",
        "Stopping patcher": "stStopping",
        "Save profile": "stPreparing",
        "Write profile": "stPreparing",
        "Starting patcher...": "stPreparing",
        "Installing Mod": "stInstalling",
        "Updating Mod": "stUpdating",
        "Delete mod": "stDeleting",
        "Acquire lock": "stLoading",
        "Check mod-tools": "stLoading",
        "Load mods": "stLoading",
        "Load profiles": "stLoading",
        "Read profile": "stLoading"
    })

    function status(text) {
        let line = text.startsWith("Status: ") ? text.substring(8) : text
        let key = statusKeys[line]
        return key !== undefined ? t(key) : text
    }

    function t(key) {
        let entry = strings[key]
        if (entry === undefined) {
            return key
        }
        return entry[language] || entry[0]
    }

    // Translates "key" or "key\u001farg1\u001farg2" messages coming from C++.
    function message(text) {
        let parts = text.split("\u001f")
        let result = t(parts[0])
        for (let i = 1; i < parts.length; i++) {
            result = result.arg(parts[i])
        }
        return result
    }
}
