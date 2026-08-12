import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { ThemeProvider } from "reacticle";
import "reacticle/styles.css";
import "./local.css";
import { Cover } from "./Cover";
import { ArticleDoc } from "./Article";

// Entry for the self-contained single-file HTML build.
// Theme is fixed here — change `theme` (must be a registered reacticle theme id:
// "tufte" | "press" | …) to switch the whole look.
//
// 渲染顺序：Cover（封面，可选）→ ArticleDoc（含 TOC + 正文 + colophon）。
// Cover 故意**不**塞进 <Article> 内部（那样会被挤到正文栏旁边），而是和 <ArticleDoc/>
// 在 ThemeProvider 下做兄弟，DOM 顺序天然就是「封面 → TOC → 正文 → colophon」。
createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <ThemeProvider theme="tufte">
      <Cover />
      <ArticleDoc />
    </ThemeProvider>
  </StrictMode>
);

// React 渲染后再处理初始深链接；否则浏览器会在 Section 尚未挂载时错过锚点。
function scrollToInitialAnchor() {
  const id = window.location.hash.slice(1);
  if (id) document.getElementById(id)?.scrollIntoView();
}
requestAnimationFrame(() => requestAnimationFrame(scrollToInitialAnchor));
window.addEventListener("hashchange", scrollToInitialAnchor);
