import { loadMappings } from 'common/assets';
import { fetchRetry } from 'tgui-core/http';
import { loadedMappings } from '../../assets';

/// --------- Handlers ------------------------------------------------------///

// META EDIT ADDITION: the server can regenerate icon_ref_map.json later on. Track the
// last url we fetched, not just whether we have any data, so a later map isn't ignored.
let lastFetchedIconRefMapUrl: string | undefined;

export function handleLoadAssets(payload: Record<string, string>): void {
  loadMappings(payload, loadedMappings);

  const iconRefMapUrl = payload['icon_ref_map.json'];
  if (
    iconRefMapUrl &&
    Byond.iconRefMap &&
    iconRefMapUrl !== lastFetchedIconRefMapUrl // META EDIT CHANGE, ORIGINAL: Object.keys(Byond.iconRefMap).length === 0
  ) {
    lastFetchedIconRefMapUrl = iconRefMapUrl; // META EDIT ADDITION
    fetchRetry(iconRefMapUrl)
      .then((res) => res.json())
      .then(setIconRefMap)
      .catch(console.error);
  }
}

/// --------- Helpers -------------------------------------------------------///

// https://biomejs.dev/linter/rules/no-assign-in-expressions/
function setIconRefMap(map: Record<string, string>): void {
  // META EDIT CHANGE, ORIGINAL: Byond.iconRefMap = map;
  Byond.iconRefMap = { ...Byond.iconRefMap, ...map };
}
