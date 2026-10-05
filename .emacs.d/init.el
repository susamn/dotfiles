;;; init.el --- Emacs configuration entry point -*- lexical-binding: t -*-

;; Load order:
;;
;;   1. package.el + MELPA bootstrap
;;   2. configuration.org  -- the literate config, identical on every machine
;;   3. profile.el         -- this machine's profile overlay, when one is linked
;;
;; profile.el is not a tracked file. do-stow.sh symlinks it to
;; .config/emacs/profiles/<profile>/profile.el for the stow-ignore profile you
;; select, so each machine gets only its own overlay and this file stays free
;; of per-machine conditionals. It loads LAST so it can override anything
;; configuration.org set -- which is how the omarchy profile takes over the
;; theme and font.
;;
;; A profile may also ship an early-init.el, linked the same way for things
;; that must run before package.el.

;;; Code:

;; Keep Custom out of this file. It is shared by every profile, so an appended
;; `custom-set-variables' block would be a tracked file going dirty on every
;; machine.
(setq custom-file (expand-file-name "custom.el" user-emacs-directory))
(when (file-exists-p custom-file)
  (load custom-file nil 'nomessage))

(require 'package)
(add-to-list 'package-archives '("gnu" . "https://elpa.gnu.org/packages/") t)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

;; No use-package means this is almost certainly a fresh machine, so refresh
;; the archives before configuration.org starts `:ensure'-ing packages.
(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(org-babel-load-file (expand-file-name "configuration.org" user-emacs-directory))

(let ((profile (expand-file-name "profile.el" user-emacs-directory)))
  (when (file-exists-p profile)
    (load profile nil 'nomessage)))

;;; init.el ends here
