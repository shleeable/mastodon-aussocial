import classNames from 'classnames';
import { useRouteMatch, NavLink } from 'react-router-dom';

import { Icon } from 'mastodon/components/icon';
import type { IconProp } from 'mastodon/components/icon';
import type { MastodonLocationDescriptor } from 'mastodon/components/router';

export const ColumnLink: React.FC<{
  icon: React.ReactNode;
  iconComponent?: IconProp;
  activeIcon?: React.ReactNode;
  activeIconComponent?: IconProp;
  isActive?: (match: unknown, location: { pathname: string }) => boolean;
  text: string;
  to?: MastodonLocationDescriptor;
  href?: string;
  transparent?: boolean;
  className?: string;
  id?: string;
}> = ({
  icon,
  activeIcon,
  iconComponent,
  activeIconComponent,
  text,
  to,
  href,
  transparent,
  ...other
}) => {
  const match = useRouteMatch(
    (typeof to === 'string' ? to : to?.pathname) ?? '',
  );
  const className = classNames('column-link', {
    'column-link--transparent': transparent,
  });
  const iconElement = iconComponent ? (
    <Icon
      id={typeof icon === 'string' ? icon : ''}
      icon={iconComponent}
      className='column-link__icon'
    />
  ) : (
    icon
  );
  const activeIconElement =
    activeIcon ??
    (activeIconComponent ? (
      <Icon
        id={typeof icon === 'string' ? icon : ''}
        icon={activeIconComponent}
        className='column-link__icon'
      />
    ) : (
      iconElement
    ));
  const active = !!match;

  if (href) {
    return (
      <a href={href} className={className} {...other}>
        {active ? activeIconElement : iconElement}
        <span>{text}</span>
      </a>
    );
  } else if (to) {
    return (
      <NavLink to={to} className={className} {...other}>
        {active ? activeIconElement : iconElement}
        <span>{text}</span>
      </NavLink>
    );
  } else {
    return null;
  }
};
