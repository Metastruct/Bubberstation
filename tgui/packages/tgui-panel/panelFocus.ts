/**
 * Basically, hacks from goonchat which try to keep the map focused at all
 * times, except for when some meaningful action happens o
 *
 * @file
 * @copyright 2020 Aleksej Komarov
 * @license MIT
 */

import { vecLength, vecSubtract } from 'tgui-core/vector';
import { focusMap } from 'tgui/focus';
import { canStealFocus, globalEvents } from 'tgui-core/events';

// Empyrically determined number for the smallest possible
// text you can select with the mouse.
const MIN_SELECTION_DISTANCE = 10;

function deferredFocusMap(): void {
  setTimeout(focusMap);
}

export function setupPanelFocusHacks(): void {
  let focusStolen = false;
  let clickStartPos: number[] | null = null;

  window.addEventListener('focusin', (e) => {
    focusStolen = canStealFocus(e.target as HTMLElement);
  });

  window.addEventListener('mousedown', (e) => {
    clickStartPos = [e.screenX, e.screenY];
  });

  window.addEventListener('mouseup', (e) => {
    if (clickStartPos) {
      const clickEndPos = [e.screenX, e.screenY];
      const dist = vecLength(vecSubtract(clickEndPos, clickStartPos));
      if (dist >= MIN_SELECTION_DISTANCE) {
        focusStolen = true;
      }
      if (document.activeElement?.className.includes('Button')) {
        focusStolen = true;
      }
    }
    if (!focusStolen) {
      deferredFocusMap();
    }
  });

  globalEvents.on('keydown', (key) => {
    if (key.isModifierKey()) {
      return;
    }
    deferredFocusMap();
  });
}

// META EDIT - ADDITION - START - STUCK_POINTER_EVENTS_FIX
/**
 * tgui-core's DraggableControl (used by Slider and friends) sets document.body.style.pointerEvents =
 * "none" for the duration of a drag, and only restores it once a "mouseup" reaches this panel's own
 * document. This panel is just one of several separately-docked BYOND browser controls sharing the same
 * game window (map, stat panel, chat, etc.), so if the drag's mouseup lands on a different one of those
 * controls instead, it never reaches here, and pointer-events stays stuck at "none" for the whole panel.
 * "blur" reliably fires the moment that happens (focus leaves this control), so use it as a safety net.
 * No known upstream fix, see https://github.com/tgstation/tgui-core.
 */
export function setupStuckPointerEventsFix(): void {
  function unstick(): void {
    if (document.body.style.pointerEvents === 'none') {
      document.body.style.pointerEvents = '';
    }
  }

  window.addEventListener('blur', unstick);
  window.addEventListener('mouseup', unstick);
  window.addEventListener('pointerup', unstick);
}
// META EDIT - ADDITION - END
