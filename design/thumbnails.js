/* Spellbook generative skill thumbnails.
 *
 * A skill or package with no real artwork gets a generated one instead of a
 * grey placeholder. The result is deterministic: the same identifiers always
 * produce the same image, across sessions and machines. Nothing is random,
 * nothing animates, nothing is cached to disk.
 *
 * Three inputs seed the drawing:
 *   palette   — from the package id, so one package reads as one family
 *   style     — from the skill id, so siblings stay distinguishable
 *   category  — inferred from package and skill text, nudging the rotation
 *
 * 7 palettes x 5 compositions = 35 stable combinations.
 *
 * Ported from the macOS implementation (FallbackThumbnailRenderer.swift,
 * FallbackThumbnailPalette.swift, FallbackThumbnailComposition.swift,
 * PackageArtwork.swift). Output is pixel-equivalent to the Swift renderer.
 *
 * Classic script, no build step, no dependencies. Loads over file://.
 */
(function (global) {
  "use strict";

  var MASK64 = (1n << 64n) - 1n;

  /* ---------------------------------------------------------------- palettes */

  // Exact opaque colors from the original fallback palettes. The former
  // transparent gradient endpoints are intentionally omitted.
  var PALETTES = [
    [0x340b05, 0x0358f7, 0x5092c7, 0xe1ecfe, 0xffd400, 0xfa3d1d, 0xfd02f5],
    [0x05122e, 0x0358f7, 0x19c3d6, 0xa8f0e0, 0x7b61ff],
    [0x2a0a05, 0x7a1f12, 0xfa3d1d, 0xffd400, 0xff7ad9],
    [0x021018, 0x0b6e4f, 0x1fd18e, 0x9cf6c8, 0x56d6e8],
    [0xff7ab6, 0xffa1d2, 0xc9a8ff, 0xa7d8ff, 0xfff3b0],
    [0x1a0400, 0x8e1600, 0xff4d00, 0xff9e1b, 0xffe7a3],
    [0x0a1a4a, 0x2b5bff, 0x6e97ff, 0xbbd0ff]
  ].map(function (rgbValues) {
    return rgbValues.map(function (rgb) {
      return (
        "#" +
        rgb.toString(16).padStart(6, "0")
      );
    });
  });

  var PALETTE_NAMES = [
    "Signal",
    "Deep water",
    "Ember",
    "Verdant",
    "Blossom",
    "Kiln",
    "Cobalt"
  ];

  var COMPOSITIONS = [
    "cropped-geometry",
    "mosaic-tiles",
    "concentric-forms",
    "radial-fan",
    "woven-strips"
  ];

  var COMPOSITION_NAMES = [
    "Cropped geometry",
    "Mosaic tiles",
    "Concentric forms",
    "Radial fan",
    "Woven strips"
  ];

  /* -------------------------------------------------------------- categories */

  var CATEGORIES = [
    ["designUI", "Design & UI"],
    ["frontend", "Frontend"],
    ["appleDevelopment", "Apple Development"],
    ["backendAPI", "Backend & APIs"],
    ["testingQA", "Testing & QA"],
    ["debugging", "Debugging"],
    ["codeReview", "Code Review"],
    ["refactoringArchitecture", "Refactoring & Architecture"],
    ["gitDevOps", "Git & DevOps"],
    ["securityPrivacy", "Security & Privacy"],
    ["dataSpreadsheets", "Data & Spreadsheets"],
    ["documents", "Documents"],
    ["researchAnalysis", "Research & Analysis"],
    ["writingEditing", "Writing & Editing"],
    ["productPlanning", "Product & Planning"],
    ["projectManagement", "Project Management"],
    ["automationAgents", "Automation & Agents"],
    ["browserWeb", "Browser & Web"],
    ["imagesGraphics", "Images & Graphics"],
    ["videoMotion", "Video & Motion"],
    ["communication", "Communication"],
    ["knowledgeNotes", "Knowledge & Notes"],
    ["learningTeaching", "Learning & Teaching"],
    ["generalUtility", "General Utility"]
  ];

  var CATEGORY_KEYWORDS = {
    designUI: ["design", "interface", "ui", "ux", "layout", "typography", "color"],
    frontend: ["frontend", "react", "css", "html", "web component", "responsive"],
    appleDevelopment: ["swift", "swiftui", "xcode", "ios", "macos", "apple"],
    backendAPI: ["backend", "api", "server", "database", "endpoint", "graphql"],
    testingQA: ["test", "qa", "tdd", "spec", "coverage", "assert"],
    debugging: ["debug", "diagnos", "trace", "xray", "inspect", "failure"],
    codeReview: ["code review", "review code", "pull request", "lint", "quality"],
    refactoringArchitecture: ["refactor", "architecture", "module", "migration", "codebase"],
    gitDevOps: ["git", "github", "deploy", "devops", "commit", "merge", "ci"],
    securityPrivacy: ["security", "privacy", "password", "credential", "permission", "auth"],
    dataSpreadsheets: ["data", "spreadsheet", "excel", "xlsx", "csv", "sheets"],
    documents: ["document", "docx", "pdf", "pptx", "slides", "presentation"],
    researchAnalysis: ["research", "analysis", "investigate", "evidence", "study"],
    writingEditing: ["writing", "writer", "edit", "article", "prose", "copy"],
    productPlanning: ["product", "plan", "roadmap", "scope", "strategy", "requirements"],
    projectManagement: ["project", "ticket", "triage", "handoff", "task", "workflow"],
    automationAgents: ["agent", "automation", "mcp", "routine", "workflow", "skill"],
    browserWeb: ["browser", "chrome", "website", "web search", "playwright", "aside"],
    imagesGraphics: ["image", "graphic", "artwork", "figma", "visual", "illustration"],
    videoMotion: ["video", "motion", "animation", "remotion", "timeline"],
    communication: ["communication", "slack", "gmail", "email", "message", "notification"],
    knowledgeNotes: ["knowledge", "notes", "notion", "obsidian", "memory", "vault"],
    learningTeaching: ["learn", "teach", "tutorial", "exercise", "explain", "onboard"],
    generalUtility: []
  };

  /* ------------------------------------------------------------ stable seeds */

  var encoder = typeof TextEncoder === "function" ? new TextEncoder() : null;

  function utf8Bytes(value) {
    if (encoder) return encoder.encode(String(value));
    var out = [];
    var text = unescape(encodeURIComponent(String(value)));
    for (var i = 0; i < text.length; i += 1) out.push(text.charCodeAt(i));
    return out;
  }

  // Package identity picks the palette: a rolling 31x hash, wrapping at 64 bits.
  function paletteIndexFor(packageId) {
    var hash = 0n;
    var bytes = utf8Bytes(packageId);
    for (var i = 0; i < bytes.length; i += 1) {
      hash = (hash * 31n + BigInt(bytes[i])) & MASK64;
    }
    return Number(hash % BigInt(PALETTES.length));
  }

  // Skill identity picks the composition: FNV-1a, also wrapping at 64 bits.
  function styleIndexFor(identifier) {
    var hash = 2166136261n;
    var bytes = utf8Bytes(identifier);
    for (var i = 0; i < bytes.length; i += 1) {
      hash = ((hash ^ BigInt(bytes[i])) * 16777619n) & MASK64;
    }
    return Number(hash % BigInt(COMPOSITIONS.length));
  }

  function categoryIndexFor(category) {
    for (var i = 0; i < CATEGORIES.length; i += 1) {
      if (CATEGORIES[i][0] === category) return i;
    }
    return 0;
  }

  // Title hits count 5, skill names 3, prose 1. A weak or contested winner
  // falls back to General Utility rather than guessing.
  function inferCategory(input) {
    var title = String((input && input.packageName) || "").toLowerCase();
    var names = ((input && input.skillNames) || []).join(" ").toLowerCase();
    var prose = String((input && input.prose) || "").toLowerCase();

    var scores = [];
    Object.keys(CATEGORY_KEYWORDS).forEach(function (category) {
      var score = 0;
      CATEGORY_KEYWORDS[category].forEach(function (keyword) {
        if (title.indexOf(keyword) !== -1) score += 5;
        if (names.indexOf(keyword) !== -1) score += 3;
        if (prose.indexOf(keyword) !== -1) score += 1;
      });
      if (score > 0) scores.push({ category: category, score: score });
    });

    scores.sort(function (a, b) {
      if (a.score !== b.score) return b.score - a.score;
      return a.category < b.category ? -1 : 1;
    });

    if (!scores.length || scores[0].score < 3) return "generalUtility";
    if (scores.length > 1 && scores[0].score - scores[1].score < 2) return "generalUtility";
    return scores[0].category;
  }

  // The full resolution a skill row performs before it draws anything.
  function thumbnailFor(input) {
    var packageId = (input && input.packageId) || "";
    var skillId = (input && input.skillId) || packageId;
    var category = (input && input.category) || inferCategory(input);
    return {
      paletteIndex: paletteIndexFor(packageId),
      styleIndex: styleIndexFor(skillId),
      categoryIndex: categoryIndexFor(category),
      category: category
    };
  }

  /* ---------------------------------------------------------------- renderer */

  function wrap(value, count) {
    var remainder = value % count;
    return remainder >= 0 ? remainder : remainder + count;
  }

  function Renderer(spec) {
    this.palette = PALETTES[wrap(spec.paletteIndex || 0, PALETTES.length)];
    this.compositionIndex = wrap(spec.styleIndex || 0, COMPOSITIONS.length);
    this.seed =
      (spec.paletteIndex || 0) * 31 +
      (spec.styleIndex || 0) * 7 +
      (spec.categoryIndex || 0);
  }

  Renderer.prototype.color = function (offset) {
    return this.palette[wrap(offset + this.seed, this.palette.length)];
  };

  Renderer.prototype.isMultipleOf = function (divisor) {
    return this.seed % divisor === 0;
  };

  Renderer.prototype.draw = function (ctx, width, height) {
    var cornerRadius = Math.min(width, height) * 0.22;

    ctx.save();
    ctx.beginPath();
    roundRectPath(ctx, 0, 0, width, height, cornerRadius);
    ctx.clip();

    ctx.fillStyle = this.color(0);
    ctx.fillRect(0, 0, width, height);

    switch (COMPOSITIONS[this.compositionIndex]) {
      case "cropped-geometry":
        this.drawCroppedGeometry(ctx, width, height);
        break;
      case "mosaic-tiles":
        this.drawMosaicTiles(ctx, width, height);
        break;
      case "concentric-forms":
        this.drawConcentricForms(ctx, width, height);
        break;
      case "radial-fan":
        this.drawRadialFan(ctx, width, height);
        break;
      case "woven-strips":
        this.drawWovenStrips(ctx, width, height);
        break;
    }

    ctx.restore();
  };

  Renderer.prototype.drawCroppedGeometry = function (ctx, width, height) {
    var mirrors = this.isMultipleOf(2);

    fillEllipse(
      ctx,
      mirrors ? width * 0.42 : width * -0.22,
      height * -0.18,
      width * 0.92,
      height * 0.92,
      this.color(2)
    );

    var slab = mirrors
      ? [
          [width * -0.18, height * 0.58],
          [width * 0.67, height * 0.38],
          [width * 1.12, height * 0.78],
          [width * 0.14, height * 1.14]
        ]
      : [
          [width * 1.18, height * 0.58],
          [width * 0.33, height * 0.38],
          [width * -0.12, height * 0.78],
          [width * 0.86, height * 1.14]
        ];
    fillPolygon(ctx, slab, this.color(4));

    var dotSize = width * 0.19;
    fillEllipse(
      ctx,
      mirrors ? width * 0.12 : width * 0.69,
      height * 0.15,
      dotSize,
      dotSize,
      this.color(1)
    );
  };

  Renderer.prototype.drawMosaicTiles = function (ctx, width, height) {
    var splitX = this.isMultipleOf(2) ? 0.58 : 0.42;
    var splitY = this.isMultipleOf(3) ? 0.46 : 0.56;

    fillRect(ctx, 0, 0, width * splitX, height * splitY, this.color(1));
    fillRect(ctx, width * splitX, 0, width * (1 - splitX), height * 0.34, this.color(3));
    fillRect(
      ctx,
      width * splitX,
      height * 0.34,
      width * (1 - splitX),
      height * (splitY - 0.34),
      this.color(2)
    );
    fillRect(ctx, 0, height * splitY, width * 0.34, height * (1 - splitY), this.color(4));
    fillRect(
      ctx,
      width * 0.34,
      height * splitY,
      width * 0.42,
      height * (1 - splitY),
      this.color(2)
    );
    fillRect(
      ctx,
      width * 0.76,
      height * splitY,
      width * 0.24,
      height * (1 - splitY),
      this.color(1)
    );
  };

  Renderer.prototype.drawConcentricForms = function (ctx, width, height) {
    var centerX = this.isMultipleOf(2) ? width * 0.66 : width * 0.34;
    var centerY = this.isMultipleOf(3) ? height * 0.36 : height * 0.66;
    var diameters = [1.38, 0.98, 0.62, 0.28];

    for (var index = 0; index < diameters.length; index += 1) {
      var diameter = width * diameters[index];
      fillEllipse(
        ctx,
        centerX - diameter / 2,
        centerY - diameter / 2,
        diameter,
        diameter,
        this.color(index + 1)
      );
    }
  };

  Renderer.prototype.drawRadialFan = function (ctx, width, height) {
    var mirrors = this.isMultipleOf(2);
    var anchor = [mirrors ? width * -0.18 : width * 1.18, height * 1.14];
    var normalized = [
      [-0.24, -0.18],
      [0.14, -0.18],
      [0.52, -0.18],
      [0.9, -0.18],
      [1.18, 0.18],
      [1.18, 0.62],
      [1.18, 1.12]
    ];
    var boundary = normalized.map(function (point) {
      return [(mirrors ? point[0] : 1 - point[0]) * width, point[1] * height];
    });

    for (var index = 0; index < boundary.length - 1; index += 1) {
      fillPolygon(
        ctx,
        [anchor, boundary[index], boundary[index + 1]],
        this.color(index + 1)
      );
    }
  };

  Renderer.prototype.drawWovenStrips = function (ctx, width, height) {
    var verticalXs = this.isMultipleOf(2) ? [0.14, 0.58] : [0.2, 0.64];
    var horizontalYs = this.isMultipleOf(3) ? [0.16, 0.58] : [0.22, 0.64];
    var stripWidth = width * 0.22;
    var stripHeight = height * 0.22;
    var index;

    for (index = 0; index < verticalXs.length; index += 1) {
      fillRoundRect(
        ctx,
        width * verticalXs[index],
        -height * 0.08,
        stripWidth,
        height * 1.16,
        stripWidth * 0.32,
        this.color(index + 1)
      );
    }

    for (index = 0; index < horizontalYs.length; index += 1) {
      fillRoundRect(
        ctx,
        -width * 0.08,
        height * horizontalYs[index],
        width * 1.16,
        stripHeight,
        stripHeight * 0.32,
        this.color(index + 3)
      );
    }

    // Re-lay the vertical strips over their crossings so the weave reads.
    for (index = 0; index < verticalXs.length; index += 1) {
      var horizontalIndex = index % horizontalYs.length;
      fillRect(
        ctx,
        width * verticalXs[index],
        height * horizontalYs[horizontalIndex],
        stripWidth,
        stripHeight,
        this.color(index + 1)
      );
    }
  };

  /* ------------------------------------------------------------- path helpers */

  function roundRectPath(ctx, x, y, width, height, radius) {
    var limit = Math.min(Math.abs(width), Math.abs(height)) / 2;
    var r = Math.max(0, Math.min(radius, limit));
    if (typeof ctx.roundRect === "function") {
      ctx.roundRect(x, y, width, height, r);
      return;
    }
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + width - r, y);
    ctx.arcTo(x + width, y, x + width, y + r, r);
    ctx.lineTo(x + width, y + height - r);
    ctx.arcTo(x + width, y + height, x + width - r, y + height, r);
    ctx.lineTo(x + r, y + height);
    ctx.arcTo(x, y + height, x, y + height - r, r);
    ctx.lineTo(x, y + r);
    ctx.arcTo(x, y, x + r, y, r);
    ctx.closePath();
  }

  function fillRect(ctx, x, y, width, height, color) {
    ctx.fillStyle = color;
    ctx.fillRect(x, y, width, height);
  }

  function fillRoundRect(ctx, x, y, width, height, radius, color) {
    ctx.fillStyle = color;
    ctx.beginPath();
    roundRectPath(ctx, x, y, width, height, radius);
    ctx.fill();
  }

  function fillEllipse(ctx, x, y, width, height, color) {
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.ellipse(x + width / 2, y + height / 2, width / 2, height / 2, 0, 0, Math.PI * 2);
    ctx.fill();
  }

  function fillPolygon(ctx, points, color) {
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.moveTo(points[0][0], points[0][1]);
    for (var index = 1; index < points.length; index += 1) {
      ctx.lineTo(points[index][0], points[index][1]);
    }
    ctx.closePath();
    ctx.fill();
  }

  /* --------------------------------------------------------------- public API */

  // Low level: paint into an existing 2D context at the given size.
  function draw(ctx, width, height, spec) {
    new Renderer(spec || {}).draw(ctx, width, height);
  }

  // High level: size a canvas for the display and paint it.
  function render(canvas, spec, size) {
    var edge = size || canvas.clientWidth || 64;
    var ratio = global.devicePixelRatio || 1;
    canvas.width = Math.round(edge * ratio);
    canvas.height = Math.round(edge * ratio);
    canvas.style.width = edge + "px";
    canvas.style.height = edge + "px";
    var ctx = canvas.getContext("2d");
    ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
    ctx.clearRect(0, 0, edge, edge);
    draw(ctx, edge, edge, spec);
    return canvas;
  }

  function toDataURL(spec, size) {
    var canvas = global.document.createElement("canvas");
    render(canvas, spec, size || 64);
    return canvas.toDataURL("image/png");
  }

  global.SpellbookThumbnails = {
    PALETTES: PALETTES,
    PALETTE_NAMES: PALETTE_NAMES,
    COMPOSITIONS: COMPOSITIONS,
    COMPOSITION_NAMES: COMPOSITION_NAMES,
    CATEGORIES: CATEGORIES,
    CATEGORY_KEYWORDS: CATEGORY_KEYWORDS,
    paletteIndexFor: paletteIndexFor,
    styleIndexFor: styleIndexFor,
    categoryIndexFor: categoryIndexFor,
    inferCategory: inferCategory,
    thumbnailFor: thumbnailFor,
    draw: draw,
    render: render,
    toDataURL: toDataURL
  };
})(typeof window !== "undefined" ? window : this);
