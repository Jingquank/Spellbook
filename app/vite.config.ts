import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));

// The app is built into app/dist and served by server/server.mjs, which also serves /design
// and /api. In dev, Vite proxies those two prefixes to a running server (npm run serve).
export default defineConfig({
  root: here,
  plugins: [react()],
  build: { outDir: path.resolve(here, "dist"), emptyOutDir: true, sourcemap: false },
  server: {
    port: 5178,
    proxy: {
      "/api": { target: process.env.SPELLBOOK_SERVER || "http://127.0.0.1:5231", changeOrigin: true },
      "/design": { target: process.env.SPELLBOOK_SERVER || "http://127.0.0.1:5231", changeOrigin: true }
    }
  }
});
