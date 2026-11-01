// THIS IS A SKYRAT UI FILE
import { type Feature, FeatureShortTextInput } from '../../base';

export const headshot: Feature<string> = {
  name: 'Headshot',
  // META EDIT - CHANGE - HEADSHOT_HOST_CONFIG - START
  /* ORIGINAL:
  description:
    'Requires a link ending with .png, .jpeg, or .jpg, starting with \
    https://, and hosted on Catbox, Imgbox, Gyazo, Lensdump, or F-List. \
    Renders the image underneath your character preview in the examine more window. \
    Image larger than 250x250 will be resized to 250x250. \
    Aim for 250x250 whenever possible',
  */
  description:
    'Requires a link, that points to the image directly. \
    Renders the image underneath your character preview in the examine more window. \
    Image larger than 250x250 will be resized to 250x250. \
    Aim for 250x250 whenever possible',
  // META EDIT - CHANGE - HEADSHOT_HOST_CONFIG - END
  component: FeatureShortTextInput,
};
