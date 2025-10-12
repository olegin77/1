import type { LayoutProps } from "next";

export const dynamic = "force-dynamic";
export const revalidate = 0;
export const fetchCache = "force-no-store";
export const dynamicParams = true;

export default function VendorsLayout(
  props: LayoutProps<"/vendors">
) {
  return <>{props.children}</>;
}
