import {
  type AgentSession,
  type ExtensionAPI,
  FooterComponent,
} from "@earendil-works/pi-coding-agent";
import { truncateToWidth } from "@earendil-works/pi-tui";

export default function sessionIdFooter(pi: ExtensionAPI) {
  pi.on("session_start", (_event, ctx) => {
    ctx.ui.setFooter((_tui, theme, footerData) => {
      // FooterComponent reads session state, usage, and subscription status from AgentSession,
      // which ExtensionContext exposes across separate fields.
      const baseFooter = new FooterComponent(
        {
          sessionManager: ctx.sessionManager,
          get model() {
            return ctx.model;
          },
          state: ctx,
          getContextUsage: () => ctx.getContextUsage(),
          modelRuntime: {
            isUsingSubscription: (provider: string) =>
              ctx.modelRegistry.isUsingOAuth(ctx.model!) &&
              ctx.modelRegistry.getProvider(provider)?.auth.oauth?.isSubscription === true,
          },
        } as unknown as AgentSession,
        footerData,
      );

      return {
        invalidate() {
          baseFooter.invalidate();
        },
        render(width: number): string[] {
          baseFooter.setAutoCompactEnabled(pi.getSettings().compaction?.enabled !== false);
          const [pwdLine, ...rest] = baseFooter.render(width);
          const sessionLine = truncateToWidth(
            theme.fg("dim", ctx.sessionManager.getSessionId()),
            width,
            theme.fg("dim", "..."),
          );
          return [pwdLine, sessionLine, ...rest];
        },
      };
    });
  });
}
