// THIS IS A META UI FILE
import { useBackend } from 'tgui/backend';
import { Box, Dropdown } from 'tgui-core/components';
import { capitalizeFirst } from 'tgui-core/string';

import type { PreferencesMenuData } from '../../../../types';
import {
  type Feature,
  type FeatureChoicedServerData,
  type FeatureValueProps,
  FeatureTriColorInput,
} from '../../base';

type TongueServerData = FeatureChoicedServerData & {
  allowed_species?: Record<string, string[]>;
};

const PREVIEW_ACTION = 'preview_custom_tongue';

function TongueStyleInput(
  props: FeatureValueProps<string, string, TongueServerData>,
) {
  const { act } = useBackend<PreferencesMenuData>();
  const { character_preferences, handleSetValue, serverData, value } = props;

  const mismatched = Boolean(
    character_preferences.secondary_features?.allow_mismatched_parts_toggle,
  );
  const species = character_preferences.misc.species;

  // Styles can be limited to the species they belong to, unless the player has
  // "Allow Mismatched Parts" on.
  const choices = (serverData?.choices ?? []).filter((name) => {
    const allowed = serverData?.allowed_species?.[name];
    if (!allowed || allowed.length === 0) {
      return true;
    }
    return mismatched || allowed.includes(species);
  });
  // Never hide the pick that's actually saved, or the dropdown would be lying.
  if (value && !choices.includes(value)) {
    choices.unshift(value);
  }

  const displayName = (name: string) =>
    capitalizeFirst(serverData?.display_names?.[name] || name);

  const options = choices.map((name) => ({
    value: name,
    displayText: (
      <Box
        width="100%"
        // Hovering an option previews it in place, so the dropdown is also the
        // preview control.
        onMouseEnter={() => act(PREVIEW_ACTION, { style: name })}
      >
        {displayName(name)}
      </Box>
    ),
  }));

  return (
    <Box
      width="100%"
      // Leaving the dropdown - button or open menu - takes the tongue back down.
      onMouseLeave={() => act(PREVIEW_ACTION, { style: null })}
    >
      <Dropdown
        buttons
        disabled={!serverData}
        displayText={value ? displayName(value) : ''}
        onSelected={handleSetValue}
        options={options}
        selected={value}
        width="100%"
      />
    </Box>
  );
}

export const feature_custom_tongue: Feature<string> = {
  name: 'Tongue Style',
  description:
    'Appearance of the tongue overlay used by the tongue and lick emotes. Hover a style to preview it. Species-specific styles are hidden unless "Allow Mismatched Parts" is on.',
  component: TongueStyleInput,
};

export const custom_tongue_color: Feature<string[]> = {
  name: 'Tongue Colors',
  description:
    'Recolors the tongue overlay. One-color styles use the first swatch; two-tone styles use the first two.',
  component: FeatureTriColorInput,
};
