#!/bin/zsh
set -euo pipefail

readonly iconoir_revision="10a66d02c6e3c94437bbf268352b1652e9eae7e5"
readonly cursor_brand_url="https://ptht05hbb1ssoooe.public.blob.vercel-storage.com/assets/brand/cursor-brand-assets.zip"
readonly claude_tile_url="https://anthropic.gallerycdn.vsassets.io/extensions/anthropic/claude-code/2.1.218/1784755560788/Microsoft.VisualStudio.Services.Icons.Default"
readonly codex_tile_url="https://openai.gallerycdn.vsassets.io/extensions/openai/chatgpt/26.5715.61943/1784654712417/Microsoft.VisualStudio.Services.Icons.Default"

readonly repository_root="${0:A:h:h}"
readonly asset_catalog="$repository_root/Packages/SpellbookKit/Sources/SpellbookUI/Resources/Icons.xcassets"
readonly attribution_directory="$repository_root/Packages/SpellbookKit/Sources/SpellbookUI/Resources/IconAttribution"
readonly temporary_directory="$(mktemp -d /tmp/spellbook-icon-assets.XXXXXX)"
trap 'rm -rf "$temporary_directory"' EXIT

git clone --quiet https://github.com/iconoir-icons/iconoir.git "$temporary_directory/iconoir"
git -C "$temporary_directory/iconoir" checkout --quiet "$iconoir_revision"

curl -L --fail --silent --show-error "$cursor_brand_url" -o "$temporary_directory/cursor-brand-assets.zip"
unzip -q "$temporary_directory/cursor-brand-assets.zip" -d "$temporary_directory/cursor"
curl -L --fail --silent --show-error "$claude_tile_url" -o "$temporary_directory/claude-code.png"
curl -L --fail --silent --show-error "$codex_tile_url" -o "$temporary_directory/codex.png"

mkdir -p "$asset_catalog" "$attribution_directory"

regular_icons=(
  search nav-arrow-right check check-circle badge-check square
  refresh refresh-double download-circle submit-document upload undo
  book book-stack page copy archive folder folder-plus package
  more-horiz settings palette cpu filter-list view-columns-3 sidebar-expand sidebar-collapse
  link link-slash server-connection network combine horizontal-split
  warning-circle warning-triangle help-circle edit-pencil media-image media-image-xmark quote
  minus-circle trash tools
)

solid_icons=(xmark-circle check-square)

write_template_imageset() {
  local source_svg="$1"
  local asset_name="$2"
  local imageset="$asset_catalog/icon-$asset_name.imageset"
  local output_svg="icon-$asset_name.svg"
  mkdir -p "$imageset"
  sed 's/stroke-width="1.5"/stroke-width="2"/g' "$source_svg" > "$imageset/$output_svg"
  printf '%s\n' \
    '{' \
    '  "images" : [' \
    '    {' \
    "      \"filename\" : \"$output_svg\"," \
    '      "idiom" : "universal"' \
    '    }' \
    '  ],' \
    '  "info" : {' \
    '    "author" : "xcode",' \
    '    "version" : 1' \
    '  },' \
    '  "properties" : {' \
    '    "preserves-vector-representation" : true,' \
    '    "template-rendering-intent" : "template"' \
    '  }' \
    '}' > "$imageset/Contents.json"
}

for icon in "${regular_icons[@]}"; do
  write_template_imageset "$temporary_directory/iconoir/icons/regular/$icon.svg" "$icon"
done

for icon in "${solid_icons[@]}"; do
  write_template_imageset "$temporary_directory/iconoir/icons/solid/$icon.svg" "$icon-solid"
done

printf '%s\n' \
  '{' \
  '  "info" : {' \
  '    "author" : "xcode",' \
  '    "version" : 1' \
  '  }' \
  '}' > "$asset_catalog/Contents.json"

write_agent_imageset() {
  local asset_name="$1"
  local source_image="$2"
  local imageset="$asset_catalog/$asset_name.imageset"
  mkdir -p "$imageset"
  cp "$source_image" "$imageset/$asset_name.png"
  printf '%s\n' \
    '{' \
    '  "images" : [' \
    '    {' \
    "      \"filename\" : \"$asset_name.png\"," \
    '      "idiom" : "universal",' \
    '      "scale" : "1x"' \
    '    }' \
    '  ],' \
    '  "info" : {' \
    '    "author" : "xcode",' \
    '    "version" : 1' \
    '  }' \
    '}' > "$imageset/Contents.json"
}

write_agent_imageset "agent-claude-code" "$temporary_directory/claude-code.png"
write_agent_imageset "agent-codex" "$temporary_directory/codex.png"

cursor_imageset="$asset_catalog/agent-cursor.imageset"
mkdir -p "$cursor_imageset"
cp "$temporary_directory/cursor/Avatars/Square/PNG/AVATAR_SQUARE_2D_LIGHT.png" "$cursor_imageset/agent-cursor-light.png"
cp "$temporary_directory/cursor/Avatars/Square/PNG/AVATAR_SQUARE_2D_DARK.png" "$cursor_imageset/agent-cursor-dark.png"
printf '%s\n' \
  '{' \
  '  "images" : [' \
  '    {' \
  '      "filename" : "agent-cursor-light.png",' \
  '      "idiom" : "universal",' \
  '      "scale" : "1x"' \
  '    },' \
  '    {' \
  '      "appearances" : [' \
  '        {' \
  '          "appearance" : "luminosity",' \
  '          "value" : "dark"' \
  '        }' \
  '      ],' \
  '      "filename" : "agent-cursor-dark.png",' \
  '      "idiom" : "universal",' \
  '      "scale" : "1x"' \
  '    }' \
  '  ],' \
  '  "info" : {' \
  '    "author" : "xcode",' \
  '    "version" : 1' \
  '  }' \
  '}' > "$cursor_imageset/Contents.json"

cp "$temporary_directory/iconoir/LICENSE" "$attribution_directory/ICONOIR-LICENSE.txt"

iconoir_sources="$attribution_directory/ICONOIR-ASSETS.tsv"
{
  printf 'asset\tupstream_path\trevision\ttransformation\n'
  for icon in "${regular_icons[@]}"; do
    printf 'icon-%s\ticons/regular/%s.svg\t%s\tstroke-width 1.5 -> 2.0\n' \
      "$icon" "$icon" "$iconoir_revision"
  done
  for icon in "${solid_icons[@]}"; do
    printf 'icon-%s-solid\ticons/solid/%s.svg\t%s\tnone\n' \
      "$icon" "$icon" "$iconoir_revision"
  done
} > "$iconoir_sources"

manifest="$attribution_directory/icon-assets.sha256"
{
  printf '# Spellbook icon asset manifest\n'
  printf '# Iconoir revision: %s\n' "$iconoir_revision"
  printf '# Regular transformation: stroke-width 1.5 -> 2.0; geometry, caps, and joins unchanged.\n'
  printf '# Cursor brand page: https://cursor.com/brand\n'
  printf '# Cursor: %s\n' "$cursor_brand_url"
  printf '# Claude Code: %s\n' "$claude_tile_url"
  printf '# Codex: %s\n' "$codex_tile_url"
  find "$asset_catalog" -type f ! -name Contents.json -print0 |
    sort -z |
    xargs -0 shasum -a 256 |
    sed "s|  $repository_root/|  |"
} > "$manifest"

printf 'Vendored %d Iconoir assets and 3 agent tiles.\n' "$(( ${#regular_icons[@]} + ${#solid_icons[@]} ))"
