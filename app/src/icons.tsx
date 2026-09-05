import { SPRITE, type IconName } from "./icons-sprite";

export function IconSprite() { return <div dangerouslySetInnerHTML={{ __html: SPRITE }} />; }

export function Icon({ name, size = "md", className }: { name: IconName; size?: "xs" | "sm" | "md"; className?: string }) {
  const cls = "i" + (size === "sm" ? " sm" : size === "xs" ? " xs" : "") + (className ? " " + className : "");
  return <svg className={cls} aria-hidden="true"><use href={"#i-" + name} /></svg>;
}
