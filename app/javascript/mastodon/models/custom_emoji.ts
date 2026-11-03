import type { RecordOf } from 'immutable';
import { Record as ImmutableRecord } from 'immutable';

import type { ApiCustomEmojiJSON } from 'mastodon/api_types/custom_emoji';

export type CustomEmojiShape = Required<ApiCustomEmojiJSON>; // no changes from server shape
export type CustomEmoji = RecordOf<CustomEmojiShape>;

export const CustomEmojiFactory = ImmutableRecord<CustomEmojiShape>({
  shortcode: '',
  static_url: '',
  url: '',
  category: '',
  featured: false,
  visible_in_picker: false,
});
