;;; early-init.el --- Omarchy profile pre-package setup -*- lexical-binding: t -*-

;; Linked to ~/.config/emacs/early-init.el by do-stow.sh when the "omarchy"
;; stow-ignore profile is selected. Emacs loads it before package.el and before
;; anything triggers native compilation, which is why the fix below cannot live
;; in profile.el or configuration.org.

;;; Code:

;; Native compilation: point libgccjit at the system GCC's runtime files.
;;
;; This machine has Homebrew alongside pacman. libgccjit invokes its compiler
;; driver by the target-versioned name (x86_64-pc-linux-gnu-gcc-<major>);
;; Homebrew's gcc formula installs a binary with that exact name, and
;; `brew shellenv' prepends Homebrew's bin to PATH, so Arch's libgccjit ends up
;; driving Homebrew's gcc. That driver emits a -L missing its target
;; subdirectory, so every .eln link dies with
;;
;;   ld: cannot find crtbeginS.o
;;   ld: cannot find -lgcc
;;
;; and Emacs falls back to bytecode without saying so. The linker is only the
;; messenger: the system ld fails on the same command line, so putting
;; /usr/bin ahead of Homebrew's ld does not help. The driver is what needs
;; fixing.
;;
;; -B names the system GCC's library directory, which is the directory the
;; driver should have found by itself. Asking gcc for the path instead of
;; hardcoding /usr/lib/gcc/<target>/<major> means a GCC major upgrade needs no
;; edit here, and on a machine without the collision it is a no-op.
;;
;; `native-comp-driver-options' is defined in comp.el, which has not loaded
;; yet -- hence `bound-and-true-p' and a plain `setq' rather than
;; `add-to-list'. Presetting is safe: the defcustom will not clobber a value
;; that is already bound.
(when (and (fboundp 'native-comp-available-p)
           (native-comp-available-p))
  (ignore-errors
    (let* ((crt (with-temp-buffer
                  (when (eq 0 (call-process "/usr/bin/gcc" nil t nil
                                            "-print-file-name=crtbeginS.o"))
                    (string-trim (buffer-string)))))
           (dir (and crt (file-name-absolute-p crt) (file-exists-p crt)
                     (file-name-directory crt)))
           (opt (and dir (concat "-B" dir))))
      (when opt
        (setq native-comp-driver-options
              (cons opt (delete opt (bound-and-true-p
                                     native-comp-driver-options))))))))

;;; early-init.el ends here
