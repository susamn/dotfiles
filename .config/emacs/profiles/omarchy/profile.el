;;; profile.el --- Omarchy profile overlay -*- lexical-binding: t -*-

;; Linked to ~/.config/emacs/profile.el by do-stow.sh when the "omarchy"
;; stow-ignore profile is selected, and loaded last by init.el.
;;
;; Loading last is deliberate. ~/.config/emacs/omarchy.el drives the theme and
;; the font from the desktop, and installs file watchers that re-apply both
;; whenever `omarchy theme set' or `omarchy font set' runs. If it loaded before
;; configuration.org, doom-one and Hack 12 would win at startup and then lose
;; the first time the desktop theme changed -- a config that behaves
;; differently in a fresh frame than in a running one. Letting Omarchy win
;; outright is the honest version; `my/toggle-theme' below flips back on
;; demand.
;;
;; omarchy.el itself is written by `omarchy-emacs-setup' and overwritten on
;; every omarchy-emacs update, so it is deliberately untracked -- it stays a
;; real local file next to the stowed symlinks.

;;; Code:

;; configuration.org enabled doom-one. Disable it so the Omarchy theme ends up
;; alone in `custom-enabled-themes': left enabled underneath, every face the
;; Omarchy theme does not define would fall through to doom-one and the result
;; is a half-and-half colour scheme rather than the desktop theme.
(disable-theme 'doom-one)

(let ((shim (expand-file-name "omarchy.el" user-emacs-directory)))
  (if (file-exists-p shim)
      (load shim nil 'nomessage)
    (message "omarchy profile selected but %s is missing -- run omarchy-emacs-setup"
             shim)))

(defun my/toggle-theme ()
  "Toggle between the Omarchy desktop theme and `doom-one'.
Under Omarchy the choice is not sticky: the theme watcher re-applies the
desktop theme on the next `omarchy theme set'."
  (interactive)
  (if (memq 'doom-one custom-enabled-themes)
      (progn
        (disable-theme 'doom-one)
        (if (fboundp 'omarchy-apply-theme)
            (progn
              (omarchy-apply-theme)
              (when (fboundp 'omarchy-apply-font) (omarchy-apply-font))
              (message "Theme: omarchy"))
          (message "Theme: none -- Omarchy integration not installed")))
    ;; omarchy-dark/omarchy-light are the pre-1.9 split themes; disable them
    ;; too so an upgraded machine doesn't leave stale faces behind.
    (dolist (theme '(omarchy omarchy-dark omarchy-light))
      (disable-theme theme))
    (load-theme 'doom-one t)
    (message "Theme: doom-one")))

(global-set-key (kbd "C-c T") #'my/toggle-theme)

;;; profile.el ends here
