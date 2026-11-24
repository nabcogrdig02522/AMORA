import type { Metadata } from "next";
import "./style.css";
export const metadata: Metadata = { title: "AMORA Founder Console", description: "Private AMORA platform administration" };
export default function RootLayout({ children }: Readonly<{children: React.ReactNode}>) {
  return <html lang="en"><body>{children}</body></html>;
}
