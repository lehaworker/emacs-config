; Elpaca init.
; ============
(defvar elpaca-installer-version 0.11)
(defvar elpaca-directory (expand-file-name "elpaca/" user-emacs-directory))
(defvar elpaca-builds-directory
  (expand-file-name (concat "builds-" emacs-version) elpaca-directory))
(defvar elpaca-repos-directory (expand-file-name "repos/" elpaca-directory))
(defvar elpaca-order '(elpaca :repo "https://github.com/progfolio/elpaca.git"
                              :ref nil :depth 1 :inherit ignore
                              :files (:defaults "elpaca-test.el" (:exclude "extensions"))
                              :build (:not elpaca--activate-package)))
(let* ((repo  (expand-file-name "elpaca/" elpaca-repos-directory))
       (build (expand-file-name "elpaca/" elpaca-builds-directory))
       (order (cdr elpaca-order))
       (default-directory repo))
  (add-to-list 'load-path (if (file-exists-p build) build repo))
  (unless (file-exists-p repo)
    (make-directory repo t)
    (when (<= emacs-major-version 28) (require 'subr-x))
    (condition-case-unless-debug err
        (if-let* ((buffer (pop-to-buffer-same-window "*elpaca-bootstrap*"))
                  ((zerop (apply #'call-process `("git" nil ,buffer t "clone"
                                                  ,@(when-let* ((depth (plist-get order :depth)))
                                                      (list (format "--depth=%d" depth) "--no-single-branch"))
                                                  ,(plist-get order :repo) ,repo))))
                  ((zerop (call-process "git" nil buffer t "checkout"
                                        (or (plist-get order :ref) "--"))))
                  (emacs (concat invocation-directory invocation-name))
                  ((zerop (call-process emacs nil buffer nil "-Q" "-L" "." "--batch"
                                        "--eval" "(byte-recompile-directory \".\" 0 'force)")))
                  ((require 'elpaca))
                  ((elpaca-generate-autoloads "elpaca" repo)))
            (progn (message "%s" (buffer-string)) (kill-buffer buffer))
          (error "%s" (with-current-buffer buffer (buffer-string))))
      ((error) (warn "%s" err) (delete-directory repo 'recursive))))
  (unless (require 'elpaca-autoloads nil t)
    (require 'elpaca)
    (elpaca-generate-autoloads "elpaca" repo)
    (let ((load-source-file-function nil)) (load "./elpaca-autoloads"))))
(add-hook 'after-init-hook #'elpaca-process-queues)
(elpaca `(,@elpaca-order))

(when (eq system-type 'windows-nt)
  (elpaca-no-symlink-mode))

;; Install use-package support
(elpaca (elpaca-use-package :wait t)
  ;; Enable use-package :ensure support for Elpaca.
  (elpaca-use-package-mode))

					; "Optimization."
					; ===============
					; https://emacs-lsp.github.io/lsp-mode/page/performance/
(setq read-process-output-max (* 4 (* 1024 1024)))
					; https://www.reddit.com/r/emacs/comments/17nl7cw/shout_out_to_the_eat_terminal_emulator_package/
(setq process-adaptive-read-buffering nil)

					; Theming.
					; ========
(when (eq system-type 'windows-nt)
  (set-frame-font "Cascadia Code 10" nil t))

					; Other.
					; ======


(use-package no-littering
  :ensure (:wait t)
  :demand t
  :config
  (require 'no-littering)
  ;; TODO: check if it's safe
  (no-littering-theme-backups))

(use-package vertico
  :ensure t
  :demand t
  :config
  (vertico-mode))

(use-package emacs
  :after (vertico)
  ;; https://github.com/minad/vertico
  :custom
  ;; Enable context menu. `vertico-multiform-mode' adds a menu in the minibuffer
  ;; to switch display modes.
  (context-menu-mode t)
  ;; Support opening new minibuffers from inside existing minibuffers.
  (enable-recursive-minibuffers t)
  ;; Hide commands in M-x which do not work in the current mode.  Vertico
  ;; commands are hidden in normal buffers. This setting is useful beyond
  ;; Vertico.
  (read-extended-command-predicate #'command-completion-default-include-p)
  ;; Do not allow the cursor in the minibuffer prompt
  (minibuffer-prompt-properties
   '(read-only t cursor-intangible t face minibuffer-prompt))
  ;; Disable case-sensitivity for file and buffer matching when built-in completion styles are used.
  (read-file-name-completion-ignore-case t)
  (read-buffer-completion-ignore-case t)
  (completion-ignore-case t))

(use-package marginalia
  :ensure t
  :demand t
  :config
  (marginalia-mode))

(use-package fzf-native
  :ensure (:repo "dangduc/fzf-native"
		 :host github
		 :files (:defaults "bin" "*.c" "*.h" "*.txt"))
  :config
  (fzf-native-load-dyn)
  (setq fussy-score-fn 'fussy-fzf-native-score))

(use-package fussy
  :ensure
  (fussy :host github :repo "jojojames/fussy")
  :after (fzf-native)
  :custom
  (fussy-score-ALL-fn 'fussy-fzf-score)
  (fussy-filter-fn 'fussy-filter-default)
  (fussy-use-cache t)
  (fussy-compare-same-score-fn 'fussy-histlen->strlen<))
;;:config
;;(fussy-setup))

(use-package orderless
  :ensure t
  :demand t
  :custom
  ;; Configure a custom style dispatcher (see the Consult wiki)
  ;; (orderless-style-dispatchers '(+orderless-consult-dispatch orderless-affix-dispatch))
  ;; (orderless-component-separator #'orderless-escapable-split-on-space)
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles partial-completion))))
  (completion-category-defaults nil) ;; Disable defaults, use our settings
  (completion-pcm-leading-wildcard t)) ;; Emacs 31: partial-completion behaves like substring

(use-package consult
  :ensure t
  :init
  ;; Tweak the register preview for `consult-register-load',
  ;; `consult-register-store' and the built-in commands.  This improves the
  ;; register formatting, adds thin separator lines, register sorting and hides
  ;; the window mode line.
  (advice-add #'register-preview :override #'consult-register-window)
  (setq register-preview-delay 0.5)

  ;; Use Consult to select xref locations with preview
  (setq xref-show-xrefs-function #'consult-xref
        xref-show-definitions-function #'consult-xref))

(use-package embark
  :ensure t
  :demand t
  :init
  ;; Optionally replace the key help with a completing-read interface
  (setq prefix-help-command #'embark-prefix-help-command))

(use-package embark-consult
  :ensure t
  :after (:all embark consult)
  :hook
  (embark-collect-mode . consult-preview-at-point-mode))

(use-package bufferlo
  :ensure t
  :demand t
  :after (consult)
  :custom
  (tab-bar-new-tab-choice #'bufferlo-create-local-scratch-buffer)
  :config
  (bufferlo-mode)
  (tab-bar-mode)
  (add-hook 'after-make-frame-functions #'bufferlo-switch-to-local-scratch-buffer)
  (defvar my:bufferlo-consult--source-local-buffers
    (list :name "Bufferlo Local Buffers"
          :narrow   ?l
          :category 'buffer
          :face     'consult-buffer
          :history  'buffer-name-history
          :state    #'consult--buffer-state
          :default  t
          :items    (lambda () (consult--buffer-query
				:predicate #'bufferlo-local-buffer-p
				:sort 'visibility
				:as #'buffer-name)))
    "Local Bufferlo buffer candidate source for `consult-buffer'.")

  (defvar my:bufferlo-consult--source-other-buffers
    (list :name "Bufferlo Other Buffers"
          :narrow   ?b
          :category 'buffer
          :face     'consult-buffer
          :history  'buffer-name-history
          :state    #'consult--buffer-state
          :items    (lambda () (consult--buffer-query
				:predicate #'bufferlo-non-local-buffer-p
				:sort 'visibility
				:as #'buffer-name)))
    "Non-local Bufferlo buffer candidate source for `consult-buffer'.")

  (setq consult-buffer-sources ())
  ;; add in the reverse order of display preference
  (add-to-list 'consult-buffer-sources 'my:bufferlo-consult--source-other-buffers)
  (add-to-list 'consult-buffer-sources 'my:bufferlo-consult--source-local-buffers))

(use-package vterm
  :ensure
  (:host github :repo "kiennq/emacs-libvterm")
  :init
  (defun leha/new-vterm-instace ()
    (interactive)
    (vterm t)))

(use-package vterm-toggle
  :ensure t
  :after (vterm)
  :custom
  (vterm-toggle-fullscreen-p nil)
  (vterm-toggle-scope 'project))
