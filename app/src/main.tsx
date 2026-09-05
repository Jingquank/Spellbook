import React from "react";
import { createRoot } from "react-dom/client";
import { ThemeProvider } from "next-themes";
import { Toaster } from "sonner";
import { App } from "./App";
import "./styles/app.css";

createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <ThemeProvider attribute="data-theme" defaultTheme="system" enableSystem storageKey="spellbook.appearance" disableTransitionOnChange>
      <App />
      <Toaster position="bottom-center" className="sb-toaster" toastOptions={{ unstyled: false, duration: 2600 }} />
    </ThemeProvider>
  </React.StrictMode>
);
