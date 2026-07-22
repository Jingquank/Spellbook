#!/usr/bin/env ruby
# frozen_string_literal: true

require "find"

root = File.expand_path("../Packages/SpellbookKit/Sources/SpellbookUI", __dir__)
exceptions = [
  %r{/SpellbookDesign\.swift$},
  %r{/SpellbookMotion\.swift$},
  %r{/FallbackThumbnail(?:Composition|Palette|Renderer|View)\.swift$},
  %r{/RepositoryArtworkView\.swift$},
  %r{/AgentIconView\.swift$}, # Official agent identity colors.
  %r{/MarkdownImageThumbnailCache\.swift$}, # Content-derived image geometry.
  %r{/ArtworkDataCache\.swift$} # Decode and cache behavior limits.
]

checks = {
  "raw spacing" => /\bspacing:\s*[1-9]\d*(?:\.\d+)?/,
  "raw padding" => /\.padding\([^\n]*?(?:,\s*|\()\s*[1-9]\d*(?:\.\d+)?\s*\)/,
  "raw frame dimension" => /\.frame\([^\n]*?(?:width|height|minWidth|maxWidth|minHeight|maxHeight):\s*[1-9]\d*(?:\.\d+)?/,
  "raw radius" => /cornerRadius:\s*[1-9]\d*(?:\.\d+)?/,
  "raw stroke" => /lineWidth:\s*(?:0\.5|1(?:\.0)?)/,
  "raw opacity" => /\.opacity\((?:0|1)?\.\d+/,
  "system font role" => /\.font\(\.(?:caption|caption2|callout|body|headline|subheadline|title\d?|largeTitle|system)\b/,
  "system semantic color" => /\.(?:foregroundStyle|background|fill|stroke|tint)\(\.(?:primary|secondary|tertiary|quaternary|separator|red|green|blue|orange|yellow|background)\b/,
  "literal color" => /Color\.(?:red|green|blue|orange|yellow|secondary|primary)\b/
}

violations = []
Find.find(root) do |path|
  next unless path.end_with?(".swift")
  next if exceptions.any? { |pattern| path.match?(pattern) }

  File.foreach(path).with_index(1) do |line, line_number|
    checks.each do |label, pattern|
      next unless line.match?(pattern)

      violations << "#{path.delete_prefix("#{root}/")}:#{line_number}: #{label}: #{line.strip}"
    end
  end
end

if violations.empty?
  puts "Design token guard passed."
  exit 0
end

warn "Design token guard found #{violations.count} orphan value(s):"
violations.each { |violation| warn "  #{violation}" }
exit 1
