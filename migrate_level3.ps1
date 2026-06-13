# TABU - Migracao Nivel 3 (Core + shared services + limpeza final) - PowerShell
# Como usar:   .\migrate_level3.ps1
# Reverter:    git checkout .

Write-Host ""
Write-Host "  TABU - Migracao Nivel 3 (Core + limpeza final)" -ForegroundColor Yellow
Write-Host ""

if (-not (Test-Path "pubspec.yaml")) {
    Write-Host "  ERRO: Execute na raiz do projeto" -ForegroundColor Red
    exit 1
}

# 1. CRIAR PASTAS
Write-Host "[1/5] Criando pastas..." -ForegroundColor Green

$dirs = @(
    "lib/core/services",
    "lib/core/services/media",
    "lib/core/widgets",
    "lib/core/helpers",
    "lib/core/controllers",
    "lib/core/shell",
    "lib/features/search/data/models",
    "lib/features/search/data/services"
)

foreach ($d in $dirs) {
    New-Item -ItemType Directory -Path $d -Force | Out-Null
}
Write-Host "   OK" -ForegroundColor Green

# 2. COPIAR ARQUIVOS
Write-Host "[2/5] Copiando arquivos..." -ForegroundColor Green

function CopyIf($src, $dst) {
    if (Test-Path $src) {
        Copy-Item $src $dst -Force
        Write-Host "   + $(Split-Path $dst -Leaf)"
    }
}

Write-Host "   -- core/services --" -ForegroundColor Cyan
CopyIf "lib/services/services_app/user_data_notifier.dart"   "lib/core/services/user_data_notifier.dart"
CopyIf "lib/services/services_app/cached_avatar.dart"        "lib/core/services/cached_avatar.dart"
CopyIf "lib/services/services_app/user_profile_cache.dart"   "lib/core/services/user_profile_cache.dart"
CopyIf "lib/services/services_app/user_avatar_service.dart"  "lib/core/services/user_avatar_service.dart"
CopyIf "lib/services/services_app/cache_service.dart"        "lib/core/services/cache_service.dart"
CopyIf "lib/services/services_app/presence_service.dart"     "lib/core/services/presence_service.dart"
CopyIf "lib/services/services_app/follow_service.dart"       "lib/core/services/follow_service.dart"
CopyIf "lib/services/services_app/chat_request_service.dart" "lib/core/services/chat_request_service.dart"

Write-Host "   -- core/services/media --" -ForegroundColor Cyan
CopyIf "lib/services/services_app/video_preload_service.dart"  "lib/core/services/media/video_preload_service.dart"
CopyIf "lib/services/services_app/video_compress_service.dart" "lib/core/services/media/video_compress_service.dart"
CopyIf "lib/services/services_app/video_watermark_service.dart""lib/core/services/media/video_watermark_service.dart"
CopyIf "lib/services/services_app/videos_trim_service.dart"    "lib/core/services/media/videos_trim_service.dart"
CopyIf "lib/services/services_app/watermark_service.dart"      "lib/core/services/media/watermark_service.dart"

Write-Host "   -- core/widgets --" -ForegroundColor Cyan
CopyIf "lib/widgets/main_navigation.dart"    "lib/core/widgets/main_navigation.dart"
CopyIf "lib/widgets/user_avatar_image.dart"  "lib/core/widgets/user_avatar_image.dart"
CopyIf "lib/widgets/user_name_text.dart"     "lib/core/widgets/user_name_text.dart"
CopyIf "lib/screens/screens_home/home_screen/home/full_screen_image.dart"        "lib/core/widgets/full_screen_image.dart"
CopyIf "lib/screens/screens_home/home_screen/home/full_screen_video.dart"        "lib/core/widgets/full_screen_video.dart"
CopyIf "lib/screens/screens_home/home_screen/home/inline_video_card.dart"        "lib/core/widgets/inline_video_card.dart"
CopyIf "lib/screens/screens_home/home_screen/home/location_permission_screen.dart""lib/core/widgets/location_permission_screen.dart"

Write-Host "   -- core/helpers --" -ForegroundColor Cyan
CopyIf "lib/widgets/imersive_helper.dart" "lib/core/helpers/imersive_helper.dart"

Write-Host "   -- core/controllers --" -ForegroundColor Cyan
CopyIf "lib/controllers/controllers_app/tabu_shell_controller.dart" "lib/core/controllers/tabu_shell_controller.dart"

Write-Host "   -- core/shell --" -ForegroundColor Cyan
CopyIf "lib/screens/screens_home/home_screen/home/tabu_shell.dart" "lib/core/shell/tabu_shell.dart"

Write-Host "   -- features (profile) --" -ForegroundColor Cyan
CopyIf "lib/services/services_app/edit_perfil_service.dart"                   "lib/features/profile/data/services/edit_perfil_service.dart"
CopyIf "lib/services/services_app/perfil_services/cached_perfil_service.dart" "lib/features/profile/data/services/cached_perfil_service.dart"
CopyIf "lib/services/services_app/perfil_services/image_preload_service.dart" "lib/features/profile/data/services/image_preload_service.dart"
CopyIf "lib/services/services_app/perfil_services/media_preload.dart"         "lib/features/profile/data/services/media_preload.dart"
CopyIf "lib/screens/screens_home/perfil_screen/perfil/perfil_screen_widgets.dart" "lib/features/profile/presentation/widgets/perfil_screen_widgets.dart"

Write-Host "   -- features (search) --" -ForegroundColor Cyan
CopyIf "lib/services/services_app/search_service.dart"           "lib/features/search/data/services/search_service.dart"
CopyIf "lib/services/services_app/search_service_paginated.dart" "lib/features/search/data/services/search_service_paginated.dart"
CopyIf "lib/services/algolia_search_service.dart"                "lib/features/search/data/services/algolia_search_service.dart"
CopyIf "lib/models/user_search.dart"                             "lib/features/search/data/models/user_search.dart"

Write-Host "   -- features (penalty) --" -ForegroundColor Cyan
CopyIf "lib/screens/screens_home/penalty_screen/penalty_screen.dart" "lib/features/penalty/presentation/pages/penalty_screen.dart"

Write-Host "   -- features (admin) --" -ForegroundColor Cyan
CopyIf "lib/services/services_app/invite_request_service.dart" "lib/features/admin/data/services/invite_request_service.dart"

# 3. ATUALIZAR IMPORTS
Write-Host "[3/5] Atualizando imports..." -ForegroundColor Green

$replacements = @(
    # core/services
    @("tabuapp/services/services_app/user_data_notifier.dart",
      "tabuapp/core/services/user_data_notifier.dart"),
    @("tabuapp/services/services_app/cached_avatar.dart",
      "tabuapp/core/services/cached_avatar.dart"),
    @("tabuapp/services/services_app/user_profile_cache.dart",
      "tabuapp/core/services/user_profile_cache.dart"),
    @("tabuapp/services/services_app/user_avatar_service.dart",
      "tabuapp/core/services/user_avatar_service.dart"),
    @("tabuapp/services/services_app/cache_service.dart",
      "tabuapp/core/services/cache_service.dart"),
    @("tabuapp/services/services_app/presence_service.dart",
      "tabuapp/core/services/presence_service.dart"),
    @("tabuapp/services/services_app/follow_service.dart",
      "tabuapp/core/services/follow_service.dart"),
    @("tabuapp/services/services_app/chat_request_service.dart",
      "tabuapp/core/services/chat_request_service.dart"),

    # core/services/media
    @("tabuapp/services/services_app/video_preload_service.dart",
      "tabuapp/core/services/media/video_preload_service.dart"),
    @("tabuapp/services/services_app/video_compress_service.dart",
      "tabuapp/core/services/media/video_compress_service.dart"),
    @("tabuapp/services/services_app/video_watermark_service.dart",
      "tabuapp/core/services/media/video_watermark_service.dart"),
    @("tabuapp/services/services_app/videos_trim_service.dart",
      "tabuapp/core/services/media/videos_trim_service.dart"),
    @("tabuapp/services/services_app/watermark_service.dart",
      "tabuapp/core/services/media/watermark_service.dart"),

    # core/widgets
    @("tabuapp/widgets/main_navigation.dart",
      "tabuapp/core/widgets/main_navigation.dart"),
    @("tabuapp/widgets/user_avatar_image.dart",
      "tabuapp/core/widgets/user_avatar_image.dart"),
    @("tabuapp/widgets/user_name_text.dart",
      "tabuapp/core/widgets/user_name_text.dart"),
    @("tabuapp/screens/screens_home/home_screen/home/full_screen_image.dart",
      "tabuapp/core/widgets/full_screen_image.dart"),
    @("tabuapp/screens/screens_home/home_screen/home/full_screen_video.dart",
      "tabuapp/core/widgets/full_screen_video.dart"),
    @("tabuapp/screens/screens_home/home_screen/home/inline_video_card.dart",
      "tabuapp/core/widgets/inline_video_card.dart"),
    @("tabuapp/screens/screens_home/home_screen/home/location_permission_screen.dart",
      "tabuapp/core/widgets/location_permission_screen.dart"),

    # core/helpers
    @("tabuapp/widgets/imersive_helper.dart",
      "tabuapp/core/helpers/imersive_helper.dart"),

    # core/controllers
    @("tabuapp/controllers/controllers_app/tabu_shell_controller.dart",
      "tabuapp/core/controllers/tabu_shell_controller.dart"),

    # core/shell
    @("tabuapp/screens/screens_home/home_screen/home/tabu_shell.dart",
      "tabuapp/core/shell/tabu_shell.dart"),

    # features/profile
    @("tabuapp/services/services_app/edit_perfil_service.dart",
      "tabuapp/features/profile/data/services/edit_perfil_service.dart"),
    @("tabuapp/services/services_app/perfil_services/cached_perfil_service.dart",
      "tabuapp/features/profile/data/services/cached_perfil_service.dart"),
    @("tabuapp/services/services_app/perfil_services/image_preload_service.dart",
      "tabuapp/features/profile/data/services/image_preload_service.dart"),
    @("tabuapp/services/services_app/perfil_services/media_preload.dart",
      "tabuapp/features/profile/data/services/media_preload.dart"),
    @("tabuapp/screens/screens_home/perfil_screen/perfil/perfil_screen_widgets.dart",
      "tabuapp/features/profile/presentation/widgets/perfil_screen_widgets.dart"),

    # features/search
    @("tabuapp/services/services_app/search_service.dart",
      "tabuapp/features/search/data/services/search_service.dart"),
    @("tabuapp/services/services_app/search_service_paginated.dart",
      "tabuapp/features/search/data/services/search_service_paginated.dart"),
    @("tabuapp/services/algolia_search_service.dart",
      "tabuapp/features/search/data/services/algolia_search_service.dart"),
    @("tabuapp/models/user_search.dart",
      "tabuapp/features/search/data/models/user_search.dart"),

    # features/penalty
    @("tabuapp/screens/screens_home/penalty_screen/penalty_screen.dart",
      "tabuapp/features/penalty/presentation/pages/penalty_screen.dart"),

    # features/admin
    @("tabuapp/services/services_app/invite_request_service.dart",
      "tabuapp/features/admin/data/services/invite_request_service.dart")
)

$allDarts = Get-ChildItem -Path "lib" -Filter "*.dart" -Recurse
$totalUpdated = 0

foreach ($r in $replacements) {
    $old = $r[0]
    $new = $r[1]
    $count = 0
    foreach ($file in $allDarts) {
        $content = [System.IO.File]::ReadAllText($file.FullName)
        if ($content.Contains($old)) {
            $content = $content.Replace($old, $new)
            [System.IO.File]::WriteAllText($file.FullName, $content)
            $count++
        }
    }
    if ($count -gt 0) {
        $shortOld = $old -replace "tabuapp/", ""
        $shortNew = $new -replace "tabuapp/", ""
        Write-Host "   $shortOld -> $shortNew ($count)" -ForegroundColor Cyan
        $totalUpdated += $count
    }
}

Write-Host "   Total: $totalUpdated arquivos atualizados" -ForegroundColor Green

# 4. REMOVER ARQUIVOS E PASTAS ANTIGOS
Write-Host "[4/5] Removendo legado..." -ForegroundColor Green

$oldFiles = @(
    "lib/services/services_app/user_data_notifier.dart",
    "lib/services/services_app/cached_avatar.dart",
    "lib/services/services_app/user_profile_cache.dart",
    "lib/services/services_app/user_avatar_service.dart",
    "lib/services/services_app/cache_service.dart",
    "lib/services/services_app/presence_service.dart",
    "lib/services/services_app/follow_service.dart",
    "lib/services/services_app/chat_request_service.dart",
    "lib/services/services_app/video_preload_service.dart",
    "lib/services/services_app/video_compress_service.dart",
    "lib/services/services_app/video_watermark_service.dart",
    "lib/services/services_app/videos_trim_service.dart",
    "lib/services/services_app/watermark_service.dart",
    "lib/services/services_app/edit_perfil_service.dart",
    "lib/services/services_app/invite_request_service.dart",
    "lib/services/services_app/search_service.dart",
    "lib/services/services_app/search_service_paginated.dart",
    "lib/services/services_app/perfil_services/cached_perfil_service.dart",
    "lib/services/services_app/perfil_services/image_preload_service.dart",
    "lib/services/services_app/perfil_services/media_preload.dart",
    "lib/services/algolia_search_service.dart",
    "lib/widgets/main_navigation.dart",
    "lib/widgets/user_avatar_image.dart",
    "lib/widgets/user_name_text.dart",
    "lib/widgets/imersive_helper.dart",
    "lib/controllers/controllers_app/tabu_shell_controller.dart",
    "lib/screens/screens_home/home_screen/home/tabu_shell.dart",
    "lib/screens/screens_home/home_screen/home/full_screen_image.dart",
    "lib/screens/screens_home/home_screen/home/full_screen_video.dart",
    "lib/screens/screens_home/home_screen/home/inline_video_card.dart",
    "lib/screens/screens_home/home_screen/home/location_permission_screen.dart",
    "lib/screens/screens_home/penalty_screen/penalty_screen.dart",
    "lib/screens/screens_home/perfil_screen/perfil/perfil_screen_widgets.dart",
    "lib/models/user_search.dart"
)

$removed = 0
foreach ($f in $oldFiles) {
    if (Test-Path $f) {
        Remove-Item $f -Force
        $removed++
    }
}
Write-Host "   $removed arquivos removidos" -ForegroundColor Green

# Limpar pastas vazias recursivamente
$foldersToCheck = @(
    "lib/services/services_app/perfil_services",
    "lib/services/services_app",
    "lib/services",
    "lib/widgets/notification",
    "lib/widgets",
    "lib/controllers/controllers_app",
    "lib/controllers",
    "lib/models",
    "lib/screens/screens_home/home_screen/home",
    "lib/screens/screens_home/home_screen/posts",
    "lib/screens/screens_home/home_screen/notification",
    "lib/screens/screens_home/home_screen",
    "lib/screens/screens_home/penalty_screen",
    "lib/screens/screens_home/perfil_screen/perfil",
    "lib/screens/screens_home/perfil_screen",
    "lib/screens/screens_home",
    "lib/screens/screens_administrative/home_screen",
    "lib/screens/screens_administrative",
    "lib/screens/screens_auth",
    "lib/screens"
)

foreach ($d in $foldersToCheck) {
    if (Test-Path $d) {
        $remaining = Get-ChildItem $d -Recurse -File -ErrorAction SilentlyContinue
        if ($null -eq $remaining -or $remaining.Count -eq 0) {
            Remove-Item $d -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "   - $d (vazio)" -ForegroundColor DarkGray
        }
    }
}

# 5. VERIFICACAO FINAL
Write-Host "[5/5] Verificando..." -ForegroundColor Green

$allDarts = Get-ChildItem -Path "lib" -Filter "*.dart" -Recurse
$clean = $true

$checks = @(
    "tabuapp/services/services_app/",
    "tabuapp/services/algolia_",
    "tabuapp/services/notification_handler",
    "tabuapp/widgets/main_navigation",
    "tabuapp/widgets/user_avatar",
    "tabuapp/widgets/user_name",
    "tabuapp/widgets/imersive",
    "tabuapp/controllers/controllers_app/",
    "tabuapp/screens/screens_home/",
    "tabuapp/models/user_search"
)

foreach ($pattern in $checks) {
    foreach ($file in $allDarts) {
        $content = [System.IO.File]::ReadAllText($file.FullName)
        if ($content.Contains($pattern)) {
            Write-Host "   AVISO: $($file.Name) ainda referencia '$pattern'" -ForegroundColor Red
            $clean = $false
        }
    }
}

if ($clean) {
    Write-Host "   Zero imports orfaos!" -ForegroundColor Green
}

# Mostrar o que sobrou em lib/ (deve ser so features/ core/ e main.dart)
Write-Host ""
Write-Host "  Estrutura final de lib/:" -ForegroundColor Yellow
$topLevel = Get-ChildItem "lib" -Directory | ForEach-Object { $_.Name }
Write-Host "   $($topLevel -join ', ')" -ForegroundColor Cyan

$remainingLegacy = Get-ChildItem "lib" -Directory | Where-Object {
    $_.Name -notin @("core", "features")
}
if ($remainingLegacy.Count -eq 0) {
    Write-Host "   Nenhuma pasta legada restante!" -ForegroundColor Green
} else {
    Write-Host "   Pastas legadas restantes: $($remainingLegacy.Name -join ', ')" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "  Migracao Nivel 3 concluida!" -ForegroundColor Green
Write-Host ""
Write-Host "  Estrutura limpa:" -ForegroundColor Cyan
Write-Host "    lib/"
Write-Host "      core/        -> services, widgets, helpers, controllers, shell"
Write-Host "      features/    -> admin, auth, chat, feed, gallery, match,"
Write-Host "                      notification, party, penalty, post, profile,"
Write-Host "                      search, settings, story, user"
Write-Host "      main.dart"
Write-Host ""
Write-Host "  Proximos passos:"
Write-Host "    flutter analyze"
Write-Host "    flutter run"
Write-Host "    Se quebrou: git checkout ."
Write-Host ""