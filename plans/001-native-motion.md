# Native motion audit and implementation

Status: implemented as part of the requested Stepsy UI refresh, based on f1b040e.

The supplied improve-animations file was used for recon and prioritization; the
user's redesign request also authorizes implementation. Its separate AUDIT.md and
PLAN-TEMPLATE.md were not included, so this plan does not claim their full audit.

## Confirmed findings and actions

1. ActivityScreen started/repeated a 900 ms sync rotation from build without
   consulting reduced-motion preferences. Replace that decorative rotation with
   a standard busy indicator and a disabled sync action during the request.
   Keep tracking, lifecycle synchronization and diagnostics in the existing flow.
2. ProgressScreen animated bar height for 220 ms and clamped every bar to at
   least 4%, making zero/no-record periods look positive. Draw recorded values
   directly, separate 0 from absent records, and use selection/semantic labels
   for feedback. Horizontal scrolling preserves minimum 48 dp bar hit regions.
3. SwissSkeletonBox repeated its 1,200 ms opacity animation unconditionally.
   Start/stop in didChangeDependencies using MediaQuery.disableAnimationsOf;
   under reduced motion stop at controller value 0.5. Onboarding's page transition
   and navigation selection also consult that OS preference.

## New progress motion

MovementRing uses a TweenAnimationBuilder<double> for the arc only, with the
shared AppTheme.motion (220 ms) and AppTheme.easeOut (Curves.easeOutCubic).
motionDuration returns Duration.zero under reduced motion. The displayed step
number is direct Text with tabular figures, so returning to the screen or
refreshing never replays a count-up. No celebration delay blocks redemption;
navigation to the saved voucher follows success immediately. No new repeating
animation or motion dependency was added.

## Checks

Run the full Flutter suite and the redesign flow suite. Check small screens,
large text and the same flow with disableAnimations enabled. Review the rendered
ring, chart, card, modal and native navigation on the connected Redmi. Tracking
must continue to use the existing provider/service, with saved steps preserved
across adb install -r. No force-stop/reboot guarantees are introduced.
