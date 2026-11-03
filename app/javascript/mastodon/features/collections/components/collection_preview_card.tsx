import classNames from 'classnames';

import type { CollectionLockupProps } from 'mastodon/features/collections/components/collection_lockup';
import { CollectionLockup } from 'mastodon/features/collections/components/collection_lockup';

import classes from './collection_preview_card.module.scss';

export const CollectionPreviewCard: React.FC<CollectionLockupProps> = ({
  collection,
  ...otherProps
}) => {
  return (
    <CollectionLockup
      collection={collection}
      className={classNames(classes.wrapper, 'collection-preview')}
      {...otherProps}
    />
  );
};
