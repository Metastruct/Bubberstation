import type {
  FeatureChoiced,
  FeatureChoicedServerData,
  FeatureValueProps,
} from '../../base';
import { FeatureDropdownInput } from '../../dropdowns';

/**
 * The server sends the picker's value together with the choices this character is
 * actually allowed to use (native styles, plus everything when "Allow Mismatched Parts"
 * is on), so other styles are never shown.
 */
type LegStyleData = {
  value?: string;
  choices?: string[];
};

export const leg_style: FeatureChoiced = {
  name: 'Legs Style',
  description:
    'Which species\' legs to draw. Other species\' styles need "Allow Mismatched Parts".',
  component: (
    props: FeatureValueProps<string, string, FeatureChoicedServerData>,
  ) => {
    const raw = props.value as unknown;
    const packed =
      typeof raw === 'object' && raw !== null
        ? (raw as LegStyleData)
        : undefined;
    const value = packed?.value ?? (raw as string);
    const serverData =
      packed?.choices && props.serverData
        ? { ...props.serverData, choices: packed.choices }
        : props.serverData;

    return (
      <FeatureDropdownInput
        buttons
        {...props}
        value={value}
        serverData={serverData}
      />
    );
  },
};
