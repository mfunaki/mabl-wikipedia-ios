import UIKit
import WMF
import SwiftUI
import WMFComponents

final class NotificationsCenterDetailViewController: ThemeableViewController, WMFNavigationBarConfiguring {

    // MARK: - Properties

    var detailView: NotificationsCenterDetailView {
        return view as! NotificationsCenterDetailView
    }

    let viewModel: NotificationsCenterDetailViewModel

    // MARK: - Lifecycle

    init(theme: Theme, viewModel: NotificationsCenterDetailViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        self.theme = theme
        hidesBottomBarWhenPushed = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let detailView = NotificationsCenterDetailView(frame: UIScreen.main.bounds)
        view = detailView

        detailView.tableView.dataSource = self
        detailView.tableView.delegate = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        configureNavigationBar()
    }
    
    private func configureNavigationBar() {
        
        let titleConfig = WMFNavigationBarTitleConfig(title: WMFLocalizedString("notifications-center-detail-title", value: "Notification Detail", comment: "Title of notification detail view, displayed after tapping a notification in Notifications Center."), customView: nil, alignment: .hidden)

        configureNavigationBar(titleConfig: titleConfig, closeButtonConfig: nil, profileButtonConfig: nil, tabsButtonConfig: nil, searchBarConfig: nil, hideNavigationBarOnScroll: false)
    }

    // MARK: - Themeable

    override func apply(theme: Theme) {
        super.apply(theme: theme)

        detailView.apply(theme: theme)
    }

}

// MARK: - UITableView

extension NotificationsCenterDetailViewController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0:
            switch indexPath.row {
            case 0:
                let cell = tableView.dequeueReusableCell(withIdentifier: NotificationsCenterDetailHeaderCell.reuseIdentifier) as? NotificationsCenterDetailHeaderCell ?? NotificationsCenterDetailHeaderCell()
                cell.configure(viewModel: viewModel, theme: theme)
                return cell
            case 1:
                let cell = tableView.dequeueReusableCell(withIdentifier: NotificationsCenterDetailContentCell.reuseIdentifier) as? NotificationsCenterDetailContentCell ?? NotificationsCenterDetailContentCell()
                cell.configure(viewModel: viewModel, theme: theme)
                return cell
            default:
                let cell = tableView.dequeueReusableCell(withIdentifier: NotificationsCenterDetailActionCell.reuseIdentifier) as? NotificationsCenterDetailActionCell ?? NotificationsCenterDetailActionCell()
                cell.configure(action: viewModel.primaryAction, theme: theme)
                return cell
            }
        default:
            let cell = tableView.dequeueReusableCell(withIdentifier: NotificationsCenterDetailActionCell.reuseIdentifier) as? NotificationsCenterDetailActionCell ?? NotificationsCenterDetailActionCell()
            cell.configure(action: viewModel.uniqueSecondaryActions[indexPath.row], theme: theme)
            return cell
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            if viewModel.primaryAction != nil {
                return 3
            }

            return 2
        default:
            return viewModel.uniqueSecondaryActions.count
        }
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let actionCell = tableView.cellForRow(at: indexPath) as? NotificationsCenterDetailActionCell else {
            return
        }

        if let actionData = actionCell.action?.actionData, let url = actionData.url {
            
            logNotificationInteraction(with: actionCell.action)
            
            let legacyNavigateAction = { [weak self] in
                
                guard let self else { return }
                var userInfo: [AnyHashable : Any] = [RoutingUserInfoKeys.source: RoutingUserInfoSourceValue.notificationsCenter.rawValue]
                
                if let replyText = viewModel.contentBody {
                    userInfo[RoutingUserInfoKeys.talkPageReplyText] = replyText as Any
                }
                
                navigate(to: url, userInfo: userInfo)
            }
            
            // first try to navigate using LinkCoordinator. If it fails, use the legacy approach.
            if let navigationController {
                
                let linkCoordinator = LinkCoordinator(navigationController: navigationController, url: url, dataStore: nil, theme: theme, articleSource: .undefined)
                let success = linkCoordinator.start()
                guard success else {
                    legacyNavigateAction()
                    return
                }
            } else {
                legacyNavigateAction()
            }
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    private func logNotificationInteraction(with action: NotificationsCenterAction?) {
        let notification = viewModel.commonViewModel.notification
        guard let notificationId = notification.id else { return }
        
        if let notificationId = Int(notificationId), let notificationType = notification.typeString, let project = notification.wiki {
            RemoteNotificationsFunnel.shared.logNotificationInteraction(
                notificationId: notificationId,
                notificationWiki: project,
                notificationType: notificationType,
                action: action?.actionData?.actionType,
                selectionToken: nil)
        }
    }
}
