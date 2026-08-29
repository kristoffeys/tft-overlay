import Foundation

/// Ensures only one instance of the app runs at a time (#7), via an
/// exclusive advisory lock (`flock`) on a file in Application Support.
/// The lock is process-scoped — released automatically when the process
/// exits, crashes, or is killed — so there's no stale-lock cleanup to get
/// wrong on the next launch.
enum SingleInstanceGuard {
    /// Kept open for the process's lifetime; closing it releases the lock.
    private static var lockFileDescriptor: Int32 = -1

    /// Attempts to become the one running instance. Returns `false` if
    /// another instance already holds the lock — the caller should
    /// terminate immediately, before registering hotkeys or showing the
    /// overlay.
    @discardableResult
    static func acquire(bundleIdentifier: String = "dev.tftoverlay.app") -> Bool {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(bundleIdentifier, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let lockPath = directory.appendingPathComponent("instance.lock").path

        let fd = open(lockPath, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else {
            // Can't even open the lock file — fail open rather than
            // refusing to launch over a filesystem hiccup.
            AppLog.lifecycle.error("Could not open single-instance lock file at \(lockPath, privacy: .public)")
            return true
        }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd)
            return false
        }
        lockFileDescriptor = fd
        return true
    }

    /// Releases the lock. Not required for correctness (the lock is
    /// process-scoped) but keeps shutdown explicit (#7).
    static func release() {
        guard lockFileDescriptor >= 0 else { return }
        close(lockFileDescriptor)
        lockFileDescriptor = -1
    }
}
