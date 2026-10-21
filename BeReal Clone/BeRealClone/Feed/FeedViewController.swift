//
//  FeedViewController.swift
//  BeReal Clone
//
//  Created by Brian Ribeiro on 11/1/22.
//

import UIKit

// TODO: Import Parse Swift
import ParseSwift


class FeedViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    private let refreshControl = UIRefreshControl()
    private var isLoadingMorePosts = false
    private var postSkip = 0
    private let postLimit = 10
    private var hasMorePosts = true
    private var canViewFeed = false
    private var commentsByPostId = [String: [Comment]]()
    
    private var posts = [Post]() {
        didSet {
            // Reload table view data any time the posts variable gets updated.
            tableView.reloadData()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
        tableView.backgroundColor = .black
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsSelection = false
        tableView.alwaysBounceVertical = true
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 550
        refreshControl.tintColor = .white
        refreshControl.addTarget(self, action: #selector(refreshPosts(_:)), for: .valueChanged)
        tableView.refreshControl = refreshControl

        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithOpaqueBackground()
        navigationBarAppearance.backgroundColor = .black
        navigationBarAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navigationBarAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        navigationController?.navigationBar.standardAppearance = navigationBarAppearance
        navigationController?.navigationBar.scrollEdgeAppearance = navigationBarAppearance
        navigationController?.navigationBar.compactAppearance = navigationBarAppearance
        navigationController?.navigationBar.tintColor = .white
        
    }
    
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let position = scrollView.contentOffset.y
        let contentHeight = scrollView.contentSize.height
        let scrollViewHeight = scrollView.frame.size.height

        if canViewFeed,
           position > contentHeight - scrollViewHeight - 1,
           !isLoadingMorePosts,
           hasMorePosts {
            isLoadingMorePosts = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.queryPosts(shouldAppend: true)
            }
        }
    }
    
    @objc private func refreshPosts(_ sender: Any) {
        checkFeedEligibility()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        checkFeedEligibility()
    }

    private func checkFeedEligibility() {
        guard let username = User.current?.username else {
            lockFeed()
            refreshControl.endRefreshing()
            return
        }

        Post.query("username" == username)
            .order([.descending("createdAt")])
            .limit(1)
            .find { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }

                    switch result {
                    case .success(let userPosts):
                        if userPosts.isEmpty {
                            self.lockFeed()
                            self.refreshControl.endRefreshing()
                        } else {
                            self.unlockFeedAndLoadPosts()
                        }
                    case .failure(let error):
                        self.refreshControl.endRefreshing()
                        self.showAlert(description: error.localizedDescription)
                    }
                }
            }
    }

    private func unlockFeedAndLoadPosts() {
        canViewFeed = true
        tableView.backgroundView = nil
        postSkip = 0
        hasMorePosts = true
        isLoadingMorePosts = false
        queryPosts(shouldAppend: false)
    }

    private func lockFeed() {
        canViewFeed = false
        posts = []
        postSkip = 0
        hasMorePosts = false
        isLoadingMorePosts = false

        let messageLabel = UILabel()
        messageLabel.text = "Create your first post to unlock the feed."
        messageLabel.textColor = .white
        messageLabel.font = .preferredFont(forTextStyle: .headline)
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        tableView.backgroundView = messageLabel
    }

    private func queryPosts(shouldAppend: Bool = false) {
        // TODO: Pt 1 - Query Posts
// https://github.com/parse-community/Parse-Swift/blob/3d4bb13acd7496a49b259e541928ad493219d363/ParseSwift.playground/Pages/2%20-%20Finding%20Objects.xcplaygroundpage/Contents.swift#L66
        
        // 1. Create a query to fetch Posts
        // 2. Any properties that are Parse objects are stored by reference in Parse DB and as such need to explicitly use `include_:)` to be included in query results.
        // 3. Sort the posts by descending order based on the created at date
        let query = Post.query()
            .include("user")
            .order([.descending("createdAt")])
            .limit(postLimit)
            .skip(postSkip)

        // Fetch objects (posts) defined in query (async)
        
        query.find { [weak self] result in
            DispatchQueue.main.async {
            self?.refreshControl.endRefreshing()
            
                switch result {
                case .success(let fetchedPosts):
                    // Update local posts property with fetched posts
                    if shouldAppend {
                        self?.posts.append(contentsOf: fetchedPosts)
                    } else {
                        self?.commentsByPostId = [:]
                        self?.posts = fetchedPosts
                    }

                    fetchedPosts.forEach { self?.fetchComments(for: $0) }
                    self?.postSkip += fetchedPosts.count
                    self?.hasMorePosts = fetchedPosts.count == self?.postLimit
                    self?.isLoadingMorePosts = false
                case .failure(let error):
                    self?.isLoadingMorePosts = false
                    self?.showAlert(description: error.localizedDescription)
                }
            }
        }


    }

    private func fetchComments(for post: Post) {
        guard let postId = post.objectId else { return }

        do {
            try Comment.query("post" == post)
                .include("user")
                .order([.ascending("createdAt")])
                .find { [weak self] result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let comments):
                            guard let self = self else { return }
                            self.commentsByPostId[postId] = comments
                            if let row = self.posts.firstIndex(where: { $0.objectId == postId }) {
                                self.tableView.reloadRows(
                                    at: [IndexPath(row: row, section: 0)],
                                    with: .none
                                )
                            }
                        case .failure(let error):
                            print("❌ Error fetching comments: \(error.localizedDescription)")
                        }
                    }
                }
        } catch {
            print("❌ Error creating comments query: \(error.localizedDescription)")
        }
    }

    private func showAddCommentAlert(for post: Post) {
        let alertController = UIAlertController(
            title: "Add Comment",
            message: nil,
            preferredStyle: .alert
        )
        alertController.addTextField { textField in
            textField.placeholder = "Write a comment"
            textField.autocapitalizationType = .sentences
        }

        let postAction = UIAlertAction(title: "Post", style: .default) { [weak self, weak alertController] _ in
            guard let self = self,
                  let text = alertController?.textFields?.first?.text?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty else { return }

            var comment = Comment()
            comment.post = post
            comment.user = User.current
            comment.username = User.current?.username
            comment.text = text

            comment.save { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        self?.fetchComments(for: post)
                    case .failure(let error):
                        self?.showAlert(description: error.localizedDescription)
                    }
                }
            }
        }

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alertController.addAction(postAction)
        present(alertController, animated: true)
    }

    private func savePhotoToLibrary(_ image: UIImage) {
        PhotoLibraryManager.shared.save(image) { [weak self] result in
            switch result {
            case .success:
                let alertController = UIAlertController(
                    title: "Saved",
                    message: "The photo was saved to your camera roll.",
                    preferredStyle: .alert
                )
                alertController.addAction(UIAlertAction(title: "OK", style: .default))
                self?.present(alertController, animated: true)
            case .failure(let error):
                self?.showAlert(description: error.localizedDescription)
            }
        }
    }

    @IBAction func onLogOutTapped(_ sender: Any) {
        showConfirmLogoutAlert()
    }

    private func showConfirmLogoutAlert() {
        let alertController = UIAlertController(title: "Log out of your account?", message: nil, preferredStyle: .alert)
        let logOutAction = UIAlertAction(title: "Log out", style: .destructive) { _ in
            NotificationCenter.default.post(name: Notification.Name("logout"), object: nil)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alertController.addAction(logOutAction)
        alertController.addAction(cancelAction)
        present(alertController, animated: true)
    }

    private func showAlert(description: String? = nil) {
        print("FEED ALERT ERROR:", description ?? "No description")

        let alertController = UIAlertController(
            title: "Oops...",
            message: "\(description ?? "Please try again...")",
            preferredStyle: .alert
        )
        let action = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(action)
        present(alertController, animated: true)
    }
}

extension FeedViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return posts.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "PostCell", for: indexPath) as? PostCell else {
            return UITableViewCell()
        }
        let post = posts[indexPath.row]
        let isOutsideViewingWindow: Bool

        if let postDate = post.createdAt {
            isOutsideViewingWindow = Date().timeIntervalSince(postDate) > 24 * 60 * 60
        } else {
            isOutsideViewingWindow = true
        }

        let comments = post.objectId.flatMap { commentsByPostId[$0] } ?? []
        cell.configure(
            with: post,
            comments: comments,
            isImageBlurred: isOutsideViewingWindow,
            onAddComment: { [weak self] in
                self?.showAddCommentAlert(for: post)
            },
            onSavePhoto: { [weak self] image in
                self?.savePhotoToLibrary(image)
            }
        )
        return cell
    }
}

extension FeedViewController: UITableViewDelegate { }
