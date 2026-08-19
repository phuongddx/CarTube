//
//  SearchResultsViewController.swift
//  CarTube
//

import UIKit

enum SearchResultsState {
    case loading
    case results([SearchResult])
    case fallback
}

final class SearchResultsViewController: UITableViewController {
    private var state: SearchResultsState = .results([])

    private let onSelect: (String) -> Void
    private let onClose: () -> Void
    private let onRetry: () -> Void

    init(onSelect: @escaping (String) -> Void, onClose: @escaping () -> Void, onRetry: @escaping () -> Void) {
        self.onSelect = onSelect
        self.onClose = onClose
        self.onRetry = onRetry
        super.init(style: .plain)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black
        tableView.backgroundColor = .black
        tableView.isOpaque = true
        tableView.rowHeight = 68.0
        tableView.separatorColor = UIColor(hue: 0, saturation: 0, brightness: 0.2, alpha: 1)
        tableView.separatorInset = .zero
        tableView.register(ResultCell.self, forCellReuseIdentifier: ResultCell.reuseIdentifier)
        tableView.register(MessageCell.self, forCellReuseIdentifier: MessageCell.reuseIdentifier)
        tableView.tableHeaderView = makeHeaderView()
    }

    private func makeHeaderView() -> UIView {
        let header = UIView(frame: CGRect(x: 0, y: 0, width: 720, height: 76))
        header.autoresizingMask = [.flexibleWidth]
        header.backgroundColor = .black

        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Close", for: .normal)
        closeButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.contentHorizontalAlignment = .left
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        let attributionLabel = UILabel()
        attributionLabel.text = "Results from YouTube"
        attributionLabel.font = .systemFont(ofSize: 13, weight: .regular)
        attributionLabel.textColor = .systemGray
        attributionLabel.textAlignment = .right
        attributionLabel.numberOfLines = 1

        [closeButton, attributionLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            header.addSubview($0)
        }

        NSLayoutConstraint.activate([
            closeButton.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            closeButton.topAnchor.constraint(equalTo: header.topAnchor, constant: 8),
            closeButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            closeButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),

            attributionLabel.leadingAnchor.constraint(greaterThanOrEqualTo: closeButton.trailingAnchor, constant: 8),
            attributionLabel.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16),
            attributionLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),

            header.bottomAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 24)
        ])

        return header
    }

    @objc private func closeTapped() {
        onClose()
    }

    func update(_ newState: SearchResultsState) {
        state = newState
        tableView.reloadData()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch state {
        case .loading, .fallback:
            return 1
        case .results(let results):
            return results.isEmpty ? 1 : min(results.count, 8)
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch state {
        case .loading:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: MessageCell.reuseIdentifier, for: indexPath) as? MessageCell else {
                return UITableViewCell()
            }
            cell.configureLoading()
            return cell
        case .fallback:
            guard let cell = tableView.dequeueReusableCell(withIdentifier: MessageCell.reuseIdentifier, for: indexPath) as? MessageCell else {
                return UITableViewCell()
            }
            cell.configureFallback()
            return cell
        case .results(let results):
            if results.isEmpty {
                guard let cell = tableView.dequeueReusableCell(withIdentifier: MessageCell.reuseIdentifier, for: indexPath) as? MessageCell else {
                    return UITableViewCell()
                }
                cell.configureNoResults()
                return cell
            }
            guard let cell = tableView.dequeueReusableCell(withIdentifier: ResultCell.reuseIdentifier, for: indexPath) as? ResultCell else {
                return UITableViewCell()
            }
            cell.configure(with: results[indexPath.row])
            return cell
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        guard case .results(let results) = state else { return }
        if results.isEmpty {
            onRetry()
            return
        }
        guard indexPath.row < results.count else { return }
        onSelect(results[indexPath.row].videoId)
    }
}

private final class ResultCell: UITableViewCell {
    static let reuseIdentifier = "ResultCell"

    private let thumbnailImageView = UIImageView()
    private let titleLabel = UILabel()
    private let channelLabel = UILabel()
    private let durationLabel = UILabel()
    private var imageTask: Task<Void, Never>?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setUpViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpViews()
    }

    private func setUpViews() {
        backgroundColor = .black

        let selectedView = UIView()
        selectedView.backgroundColor = UIColor(red: 28 / 255.0, green: 28 / 255.0, blue: 30 / 255.0, alpha: 1)
        selectedBackgroundView = selectedView

        thumbnailImageView.contentMode = .scaleAspectFill
        thumbnailImageView.clipsToBounds = true
        thumbnailImageView.layer.cornerRadius = 8
        thumbnailImageView.backgroundColor = UIColor(red: 28 / 255.0, green: 28 / 255.0, blue: 30 / 255.0, alpha: 1)

        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byTruncatingTail

        channelLabel.font = .systemFont(ofSize: 17, weight: .regular)
        channelLabel.textColor = .white
        channelLabel.numberOfLines = 1
        channelLabel.lineBreakMode = .byTruncatingTail

        durationLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .regular)
        durationLabel.textColor = .white
        durationLabel.numberOfLines = 1

        [thumbnailImageView, titleLabel, channelLabel, durationLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            thumbnailImageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            thumbnailImageView.widthAnchor.constraint(equalToConstant: 106),
            thumbnailImageView.heightAnchor.constraint(equalToConstant: 60),

            titleLabel.leadingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),

            channelLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            channelLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            channelLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),

            durationLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            durationLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            durationLabel.topAnchor.constraint(equalTo: channelLabel.bottomAnchor, constant: 2),
            durationLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -16)
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageTask?.cancel()
        imageTask = nil
        thumbnailImageView.image = nil
        thumbnailImageView.backgroundColor = UIColor(red: 28 / 255.0, green: 28 / 255.0, blue: 30 / 255.0, alpha: 1)
    }

    func configure(with result: SearchResult) {
        titleLabel.text = result.title
        channelLabel.text = result.channel

        if let durationText = DurationFormatter.display(result.duration) {
            durationLabel.text = durationText
            durationLabel.isHidden = false
        } else {
            durationLabel.isHidden = true
        }

        thumbnailImageView.image = nil

        guard let url = result.thumbnail else { return }
        imageTask = Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
            guard !Task.isCancelled, let image = UIImage(data: data) else { return }
            await MainActor.run {
                self?.thumbnailImageView.image = image
            }
        }
    }
}

private final class MessageCell: UITableViewCell {
    static let reuseIdentifier = "MessageCell"

    private let spinner = UIActivityIndicatorView(style: .medium)
    private let headingLabel = UILabel()
    private let bodyLabel = UILabel()
    private let actionLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setUpViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpViews()
    }

    private func setUpViews() {
        backgroundColor = .black
        selectionStyle = .none

        spinner.color = .systemRed

        headingLabel.textColor = .white
        headingLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        headingLabel.textAlignment = .center
        headingLabel.numberOfLines = 0

        bodyLabel.font = .systemFont(ofSize: 17, weight: .regular)
        bodyLabel.textAlignment = .center
        bodyLabel.numberOfLines = 0

        actionLabel.textColor = .systemRed
        actionLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        actionLabel.textAlignment = .center
        actionLabel.numberOfLines = 1

        let stack = UIStackView(arrangedSubviews: [spinner, headingLabel, bodyLabel, actionLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -24),
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    func configureLoading() {
        spinner.isHidden = false
        spinner.startAnimating()
        headingLabel.isHidden = true
        bodyLabel.text = "Searching…"
        bodyLabel.textColor = .white
        bodyLabel.isHidden = false
        actionLabel.isHidden = true
    }

    func configureNoResults() {
        spinner.isHidden = true
        spinner.stopAnimating()
        headingLabel.text = "No results"
        headingLabel.isHidden = false
        bodyLabel.text = "Nothing matched that search."
        bodyLabel.textColor = .systemGray
        bodyLabel.isHidden = false
        actionLabel.text = "Try another search"
        actionLabel.isHidden = false
    }

    func configureFallback() {
        spinner.isHidden = false
        spinner.startAnimating()
        headingLabel.text = "Search unavailable"
        headingLabel.isHidden = false
        bodyLabel.text = "Showing YouTube web search instead."
        bodyLabel.textColor = .systemGray
        bodyLabel.isHidden = false
        actionLabel.isHidden = true
    }
}
