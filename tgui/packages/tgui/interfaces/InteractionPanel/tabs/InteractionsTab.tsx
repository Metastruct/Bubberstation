// THIS IS A META UI FILE
import { useMemo } from 'react';
import {
  Box,
  Button,
  Collapsible,
  Icon,
  NoticeBox,
  Section,
  Stack,
} from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';

import { useBackend } from '../../../backend';

type InteractionFeedback = {
  specialized: BooleanLike;
  sound: BooleanLike;
  status_effect: BooleanLike;
  decal: BooleanLike;
  force_say: BooleanLike;
  emote: BooleanLike;
};

type Interaction = {
  categories: string[];
  interactions: Record<string, string[]>;
  descriptions: Record<string, string>;
  colors: Record<string, string>;
  feedback: Record<string, InteractionFeedback>;
  self: string;
  ref_self: string;
  ref_user: string;
  block_interact: BooleanLike;
  combat_mode: BooleanLike;
  target_zone: string;
  target_prone: BooleanLike;
  isTargetSelf: BooleanLike;
};

type InteractionsTabProps = {
  searchText: string;
  showCategories: boolean;
};

// Matches the BODY_ZONE_* string values sent from the backend.
const ZONE_NAMES: Record<string, string> = {
  head: 'Head',
  chest: 'Chest',
  l_arm: 'Left Arm',
  r_arm: 'Right Arm',
  l_leg: 'Left Leg',
  r_leg: 'Right Leg',
  eyes: 'Eyes',
  mouth: 'Mouth',
  groin: 'Groin',
  l_hand: 'Left Hand',
  r_hand: 'Right Hand',
  l_foot: 'Left Foot',
  r_foot: 'Right Foot',
};

const formatZone = (zone: string) => ZONE_NAMES[zone] || zone;

type Badge = {
  icon: string;
  label: string;
};

// "sound" isn't included here since it's shown via the button's primary icon instead (see
// primaryIcon below) rather than as a trailing badge, so it doesn't need its own tooltip text.
const badgesFor = (feedback: InteractionFeedback | undefined): Badge[] => {
  if (!feedback) return [];
  const badges: Badge[] = [];
  if (feedback.status_effect) {
    badges.push({ icon: 'biohazard', label: 'Applies a status effect' });
  }
  if (feedback.decal) {
    badges.push({ icon: 'paint-brush', label: 'Leaves a mark behind' });
  }
  if (feedback.force_say) {
    badges.push({ icon: 'comment-dots', label: 'Interrupts speech' });
  }
  if (feedback.emote) {
    badges.push({ icon: 'theater-masks', label: 'Forces an emote' });
  }
  return badges;
};

export const InteractionsTab = (props: InteractionsTabProps) => {
  const { act, data } = useBackend<Interaction>();
  const {
    categories = [],
    interactions = {},
    descriptions = {},
    colors = {},
    feedback = {},
    ref_self,
    ref_user,
    block_interact,
    combat_mode,
    target_zone,
    target_prone,
    isTargetSelf,
  } = data;
  const { searchText, showCategories } = props;

  const searchLower = searchText.toLowerCase();

  const renderInteractionButton = (interaction: string) => {
    const interactionFeedback = feedback[interaction];
    const badges = badgesFor(interactionFeedback);
    const specialized = !!interactionFeedback?.specialized;

    // Self-overrides are checked before combat/prone on the backend (see get_zone_data), so
    // when targeting yourself that's what actually fires, regardless of combat mode or posture.
    const primaryIcon = specialized
      ? isTargetSelf
        ? 'user'
        : combat_mode
          ? 'fist-raised'
          : target_prone
            ? 'bed'
            : 'exclamation-circle'
      : interactionFeedback?.sound
        ? 'volume-up'
        : 'exclamation-circle';

    const tooltipLines = [descriptions[interaction]];
    if (badges.length > 0) {
      tooltipLines.push(badges.map((badge) => badge.label).join(' • '));
    }
    if (specialized) {
      tooltipLines.push(
        isTargetSelf
          ? 'Has special phrasing for using this on yourself.'
          : 'Behaves differently with your current target/mode.',
      );
    }

    return (
      <Button
        key={interaction}
        width="150px"
        lineHeight={1.75}
        disabled={block_interact}
        color={block_interact ? 'grey' : colors[interaction]}
        tooltip={
          block_interact
            ? 'You cannot interact right now'
            : tooltipLines.filter(Boolean).join('\n')
        }
        icon={primaryIcon}
        onClick={() =>
          act('interact', {
            interaction: interaction,
            selfref: ref_self,
            userref: ref_user,
          })
        }
      >
        {interaction}
        {badges.map((badge) => (
          <Icon
            key={badge.icon}
            name={badge.icon}
            size={0.7}
            opacity={0.65}
            ml={0.5}
            verticalAlign="middle"
          />
        ))}
      </Button>
    );
  };

  const filterInteractions = (category: string) => {
    let categoryInteractions = interactions[category] || [];
    if (searchText) {
      categoryInteractions = categoryInteractions.filter(
        (interaction) =>
          interaction.toLowerCase().includes(searchLower) ||
          (descriptions[interaction] || '').toLowerCase().includes(searchLower),
      );
    }
    return categoryInteractions;
  };

  const allInteractions = useMemo(() => {
    return categories.flatMap((category) =>
      filterInteractions(category).map((interaction) => ({
        name: interaction,
        category,
      })),
    );
  }, [categories, searchLower]);

  return (
    <Stack fill vertical>
      <NoticeBox>
        {block_interact ? 'Unable to Interact' : 'Able to Interact'}
      </NoticeBox>
      <Stack.Item>
        <Section>
          <Stack align="center" wrap>
            <Stack.Item grow>
              <Icon name="crosshairs" mr={1} />
              Targeting: <b>{formatZone(target_zone)}</b>
            </Stack.Item>
            <Stack.Item>
              <Box inline color={combat_mode ? 'bad' : 'good'} bold>
                <Icon
                  name={combat_mode ? 'fist-raised' : 'hand-paper'}
                  mr={0.5}
                />
                Combat Mode {combat_mode ? 'ON' : 'OFF'}
              </Box>
            </Stack.Item>
            {!!target_prone && (
              <Stack.Item>
                <Box inline color="average" bold>
                  <Icon name="bed" mr={0.5} />
                  Target Lying Down
                </Box>
              </Stack.Item>
            )}
            {!!isTargetSelf && (
              <Stack.Item>
                <Box inline color="blue" bold>
                  <Icon name="user" mr={0.5} />
                  Targeting Yourself
                </Box>
              </Stack.Item>
            )}
          </Stack>
        </Section>
      </Stack.Item>
      <Stack.Item grow>
        {showCategories ? (
          categories.map((category) => {
            const filteredInteractions = filterInteractions(category);
            if (filteredInteractions.length === 0) return null;
            return (
              <Collapsible
                key={category}
                title={category}
                buttons={
                  <Box inline color="grey" fontSize={0.9}>
                    {filteredInteractions.length}
                    {' interactions'}
                  </Box>
                }
              >
                <Section fill>
                  <Box mt={0.2}>
                    {filteredInteractions.map((interaction) =>
                      renderInteractionButton(interaction),
                    )}
                  </Box>
                </Section>
              </Collapsible>
            );
          })
        ) : (
          <Section fill>
            <Box mt={0.2}>
              {allInteractions.map(({ name, category }) =>
                renderInteractionButton(name),
              )}
            </Box>
          </Section>
        )}
      </Stack.Item>
    </Stack>
  );
};
