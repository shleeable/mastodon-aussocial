import { useState, useCallback } from 'react';

import classNames from 'classnames';
import { Link } from 'react-router-dom';

import { useHovering } from 'mastodon/hooks/useHovering';
import { autoPlayGif } from 'mastodon/initial_state';
import type { Account, AccountShapeFull } from 'mastodon/models/account';

import { useAccount } from '../hooks/useAccount';

interface Props {
  account?: Pick<
    Account | AccountShapeFull,
    'id' | 'acct' | 'avatar' | 'avatar_static'
  >;
  alt?: string;
  size?: number;
  animate?: boolean;
  withLink?: boolean;
  counter?: number | string;
  className?: string;
}

export const Avatar: React.FC<Props> = ({
  account,
  alt = '',
  animate = autoPlayGif,
  size = 20,
  withLink = false,
  className,
  counter,
}) => {
  const { hovering, handleMouseEnter, handleMouseLeave } = useHovering(animate);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(false);

  const style = {
    width: `${size}px`,
    height: `${size}px`,
  };

  const src = hovering || animate ? account?.avatar : account?.avatar_static;

  const handleLoad = useCallback(() => {
    setLoading(false);
  }, [setLoading]);

  const handleError = useCallback(() => {
    setError(true);
  }, [setError]);

  const avatar = (
    <span
      className={classNames(className, 'account__avatar', {
        'account__avatar--loading': loading,
      })}
      onMouseEnter={handleMouseEnter}
      onMouseLeave={handleMouseLeave}
      style={style}
    >
      {src && !error && (
        <img src={src} alt={alt} onLoad={handleLoad} onError={handleError} />
      )}

      {counter && <span className='account__avatar__counter'>{counter}</span>}
    </span>
  );

  if (withLink) {
    return (
      <Link
        to={`/@${account?.acct}`}
        title={`@${account?.acct}`}
        data-hover-card-account={account?.id}
      >
        {avatar}
      </Link>
    );
  }

  return avatar;
};

export const AvatarById: React.FC<
  { accountId: string | undefined } & Omit<Props, 'account'>
> = ({ accountId, ...otherProps }) => {
  const account = useAccount(accountId);
  return <Avatar account={account} {...otherProps} />;
};
