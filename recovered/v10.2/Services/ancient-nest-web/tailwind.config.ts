import type { Config } from "tailwindcss";
export default {
 content: ["./app/**/*.{ts,tsx}", "./components/**/*.{ts,tsx}"],
 theme: { extend: { colors: { stone: { 950: "#101412" }, gold: "#d3b675", plasma: "#94c3a3" } } },
 plugins: [],
} satisfies Config;
