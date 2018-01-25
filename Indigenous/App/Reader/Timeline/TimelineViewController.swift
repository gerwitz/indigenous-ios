//
//  TimelineViewController.swift
//  Indigenous
//
//  Created by Edward Hinkle on 12/20/17.
//  Copyright © 2017 Studio H, LLC. All rights reserved.
//
import UIKit
import Social
import MobileCoreServices
import SafariServices

class TimelineViewController: UITableViewController, UITableViewDataSourcePrefetching, PostingViewDelegate {
    
    var channel: Channel? = nil
    var timeline: Timeline? = nil
    var fetchingOlderData: Bool = false
    var fetchingNewerData: Bool = false
    var previousDataAvailable: Bool = true
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return timeline?.posts.count ?? 0
        } else {
            return 1
        }
    }
    
    @IBAction func handleRefresh(_ sender: UIRefreshControl) {
        if !fetchingNewerData {
            fetchingNewerData = true
            
            timeline?.getNextTimeline { error, newPosts in
                guard error == nil else {
                    print("Error while fetching timeline")
                    print(error)
                    self.fetchingNewerData = false
                    DispatchQueue.main.async {
                        sender.endRefreshing()
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    if let newPostsCount = newPosts?.count {
                        let indexPaths = (0..<newPostsCount).map { IndexPath(row: $0, section: 0) }
                        self.tableView.insertRows(at: indexPaths, with: .automatic)
                    }
                    self.fetchingNewerData = false
                    sender.endRefreshing()
                }
            }
        } else {
            sender.endRefreshing()
        }
    }
    
    func tableView(tableView: UITableView, estimatedHeightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        // Estimate height based on if a photo exists
        let post = timeline!.posts[indexPath.row]
        var cellHeight: CGFloat = 160
        
        if let photoCount = post.photo?.count, photoCount > 0 {
            cellHeight += 200
        }
        
        return cellHeight
    }
    
    // TODO: I'd love to get this autoscrolling load to work, but right now it makes you lose your position
//    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
//        let contentHeight = scrollView.contentSize.height
//        let actualPosition = scrollView.contentOffset.y
//        let refreshBoundary = scrollView.contentSize.height - (tableView.frame.size.height * 2);
//
//        if !fetchingOlderData, contentHeight > 0, actualPosition > 0 {
////            let refreshBoundary = scrollView.contentSize.height - tableView.frame.size.height;
//
//            if (actualPosition >= refreshBoundary) {
//                fetchingOlderData = true
//                timeline?.getPreviousTimeline { error, newPosts in
//                    guard error == nil else {
//                        print("Error while fetching previous timeline")
//                        print(error)
//                        return
//                    }
//
//                    DispatchQueue.main.async {
//                        if let allPostsCount = self.timeline?.posts.count, let newPostsCount = newPosts?.count {
//                            let indexPaths = (allPostsCount - newPostsCount ..< allPostsCount).map { IndexPath(row: $0, section: 0) }
//                            self.tableView.insertRows(at: indexPaths, with: .none)
//                        }
//                        self.fetchingOlderData = false
//                    }
//                }
//            }
//        }
//    }
    
    func tableView(_ tableView: UITableView, prefetchRowsAt indexPaths: [IndexPath]) {
        for indexPath in indexPaths {
            if indexPath.section == 0 {
                let post = timeline!.posts[indexPath.row]
                if post.photo != nil, post.photo!.count > 0 {
                    post.downloadPhoto(photoIndex: 0)
                }
                if post.author?.photo != nil, post.author!.photo!.count > 0 {
                    post.author?.downloadPhoto(photoIndex: 0)
                }
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let replyAction = UIContextualAction(style: .normal, title:  "Reply", handler: { (ac:UIContextualAction, view:UIView, success:(Bool) -> Void) in
            
            let post = self.timeline!.posts[indexPath.row]
            
            self.performSegue(withIdentifier: "showReplyView", sender: post)
            success(true)
        })
        
        replyAction.image = UIImage(named: "tick")
        replyAction.backgroundColor = #colorLiteral(red: 0.4392156899, green: 0.01176470611, blue: 0.1921568662, alpha: 1)

        return UISwipeActionsConfiguration(actions: [replyAction])
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let viewAction = UIContextualAction(style: .normal, title:  "View", handler: { (ac:UIContextualAction, view:UIView, success:(Bool) -> Void) in
            
            let post = self.timeline!.posts[indexPath.row]
            
            if let postUrl = post.url {
                let safariVC = SFSafariViewController(url: postUrl)
                self.present(safariVC, animated: true)
                success(true)
            } else {
                success(false)
            }
        })
        viewAction.image = UIImage(named: "tick")
        viewAction.backgroundColor = #colorLiteral(red: 0.4392156899, green: 0.01176470611, blue: 0.1921568662, alpha: 1)
        
        return UISwipeActionsConfiguration(actions: [viewAction])
        
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if indexPath.section == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "LoadMoreTimelineCell", for: indexPath)
            cell.textLabel?.text = previousDataAvailable ? "Load More Posts" : "No More Posts"
            return cell
        }
        
        let post = timeline!.posts[indexPath.row]
        
        if let photoCount = post.photo?.count, photoCount > 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "PhotoTimelineCell", for: indexPath) as! TimelinePhotoTableViewCell
            cell.setContent(ofPost: post)
            return cell
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "TextTimelineCell", for: indexPath) as! TimelineTextTableViewCell
        cell.setContent(ofPost: post)
        return cell
        
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        if indexPath.section == 1 {
            timeline?.getPreviousTimeline { error, newPosts in
                DispatchQueue.main.async {
                    guard error == nil else {
                        print("Error while fetching timeline")
                        print(error)
                        self.previousDataAvailable = false
                        tableView.reloadRows(at: [IndexPath(row: 0, section: 1)], with: .automatic)
                        return
                    }
                    
                    if let allPostsCount = self.timeline?.posts.count, let newPostsCount = newPosts?.count {
                        let indexPaths = (allPostsCount - newPostsCount ..< allPostsCount).map { IndexPath(row: $0, section: 0) }
                        self.tableView.insertRows(at: indexPaths, with: .automatic)
                    }
                    self.fetchingOlderData = false
                }
            }
        }
        
        
        //let defaults = UserDefaults(suiteName: "group.software.studioh.indigenous")
        
//        let post = timeline[indexPath.row]
//
//        if let postUrl = post.url {
//            let safariVC = SFSafariViewController(url: postUrl)
//            present(safariVC, animated: true, completion: nil)
//        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.prefetchDataSource = self
        
        let defaults = UserDefaults(suiteName: "group.software.studioh.indigenous")
        let activeAccount = defaults?.integer(forKey: "activeAccount") ?? 0
        if let micropubAccounts = defaults?.array(forKey: "micropubAccounts") as? [Data],
            let account = try? JSONDecoder().decode(IndieAuthAccount.self, from: micropubAccounts[activeAccount]) {
         
                print("about to load timeline")
            
                timeline = Timeline()
                timeline?.accountDetails = account
                timeline?.channel = self.channel!
                timeline?.getTimeline { error, _ in
                    guard error == nil else {
                        print("Error while fetching main timeline")
                        print(error)
                        return
                    }
                    
                    DispatchQueue.main.async {
                        self.tableView.reloadData()
                    }

                    if let postsCount = self.timeline?.posts.count {
                        let totalRowsToPrefetch = postsCount < 9 ? postsCount : 8
                        for row in 0..<totalRowsToPrefetch {
                            print("Prefetching for row \(row)")
                            if let post = self.timeline?.posts[row] {
                                if post.photo != nil, post.photo!.count > 0 {
                                    post.downloadPhoto(photoIndex: 0)
                                }
                                if post.author?.photo != nil, post.author!.photo!.count > 0 {
                                    post.author?.downloadPhoto(photoIndex: 0)
                                }
                            }
                        }
                    }

                }
        }
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        var destinationViewController: UIViewController? = segue.destination
        if let navigationController = destinationViewController as? UINavigationController {
            destinationViewController = navigationController.visibleViewController
        }
        
        if segue.identifier == "showReplyView" {
            if let postingVC = destinationViewController as? PostingViewController {
                postingVC.currentPost = MicropubPost(type: .entry,
                                                     properties: MicropubPostProperties())
                
                if let replyPost = sender as? Jf2Post {
                    postingVC.currentPost?.properties.inReplyTo = replyPost.url?.absoluteString
                }
                
                postingVC.displayAsModal = false
                postingVC.delegate = self
                postingVC.title = "New Reply"
            }
        }
    }
    
    func removePostingView() {
        navigationController?.popViewController(animated: true)
    }
    
}
