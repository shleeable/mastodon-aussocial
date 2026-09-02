import { Provider } from 'react-redux';

import { configureStore } from '@reduxjs/toolkit';
import { Map as ImmutableMap } from 'immutable';

import { render, screen } from '@/testing/rendering';
import { accountFactoryImmutable } from '@/testing/factories';
import type { NotificationGroupAdminReport } from 'mastodon/models/notification_group';
import { reducerWithInitialState } from 'mastodon/reducers';

import { NotificationAdminReport } from '../notification_admin_report';

describe('<NotificationAdminReport />', () => {
  const reporterAccount = accountFactoryImmutable({
    id: '1',
    acct: 'reporter',
    username: 'reporter',
    display_name: 'Reporter User',
  });

  const localTargetAccount = accountFactoryImmutable({
    id: '2',
    acct: 'local_user',
    username: 'local_user',
    display_name: 'Local User',
  });

  const remoteTargetAccount = accountFactoryImmutable({
    id: '3',
    acct: 'remote_user@example.com',
    username: 'remote_user',
    display_name: 'Remote User',
  });

  const createMockStore = (accountsMap: Record<string, ReturnType<typeof accountFactoryImmutable>>) =>
    configureStore({
      reducer: reducerWithInitialState({
        accounts: ImmutableMap(accountsMap),
      }),
      middleware: (getDefaultMiddleware) =>
        getDefaultMiddleware({ serializableCheck: false, immutableCheck: false }),
    });

  it('renders (local) suffix when reported account is local', () => {
    const store = createMockStore({
      '1': reporterAccount,
      '2': localTargetAccount,
    });

    const notification: NotificationGroupAdminReport = {
      type: 'admin.report',
      group_key: 'report-1',
      notifications_count: 1,
      most_recent_notification_id: '1',
      page_max_id: '1',
      page_min_id: '1',
      latest_page_notification_at: '2023-01-01T00:00:00.000Z',
      sampleAccountIds: ['1'],
      partial: false,
      report: {
        id: 'rep-1',
        action_taken: false,
        action_taken_at: null,
        forwarded: false,
        category: 'spam',
        comment: 'Spamming posts',
        created_at: '2023-01-01T00:00:00.000Z',
        status_ids: ['10', '11', '12', '13'],
        rule_ids: [],
        targetAccountId: '2',
      },
    };

    render(
      <Provider store={store}>
        <NotificationAdminReport notification={notification} />
      </Provider>,
    );

    expect(screen.getByRole('heading', { level: 2 }).textContent).toContain(
      'Reporter User reported 4 posts from Local User (local) for spam',
    );
  });

  it('renders (remote) suffix when reported account is remote', () => {
    const store = createMockStore({
      '1': reporterAccount,
      '3': remoteTargetAccount,
    });

    const notification: NotificationGroupAdminReport = {
      type: 'admin.report',
      group_key: 'report-2',
      notifications_count: 1,
      most_recent_notification_id: '2',
      page_max_id: '2',
      page_min_id: '2',
      latest_page_notification_at: '2023-01-01T00:00:00.000Z',
      sampleAccountIds: ['1'],
      partial: false,
      report: {
        id: 'rep-2',
        action_taken: false,
        action_taken_at: null,
        forwarded: false,
        category: 'spam',
        comment: 'Spamming posts',
        created_at: '2023-01-01T00:00:00.000Z',
        status_ids: ['10', '11', '12', '13'],
        rule_ids: [],
        targetAccountId: '3',
      },
    };

    render(
      <Provider store={store}>
        <NotificationAdminReport notification={notification} />
      </Provider>,
    );

    expect(screen.getByRole('heading', { level: 2 }).textContent).toContain(
      'Reporter User reported 4 posts from Remote User (remote) for spam',
    );
  });
});
