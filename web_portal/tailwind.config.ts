import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: "#D4AF37", // Accent Gold
          dark: "#B58C28",
          light: "#E0C17E",
        },
        secondary: {
          DEFAULT: "#1F1F1F", // App Background
          dark: "#121212",
          light: "#2C2C2C", // Card Background
        },
        gold: {
          light: "#EEE593", // App Text Color
          rich: "#D4AF37",
        }
      },
      backgroundImage: {
        "gold-gradient": "linear-gradient(to right, #E0C17E, #D4AF37, #B58C28)", // Improved matching
        "dark-gradient": "radial-gradient(circle at center, #2C2C2C 0%, #1F1F1F 100%)",
      },
    },
  },
  plugins: [],
};
export default config;
