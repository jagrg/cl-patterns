;;;; cl-patterns-skeletons.el --- collection of cl-patterns-related skeletons. -*- lexical-binding: t; -*-

;; Copyright (C) 2021 modula t.

;; Author: modula t. <defaultxr AT gmail DOT com>
;; Homepage: https://github.com/defaultxr/cl-patterns
;; Version: 0.5
;; Package-Requires: ((emacs "24.4"))
;; Keywords: convenience, lisp

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;; These are just a few skeletons for various cl-patterns-related constructs.
;; They're designed to be as "smart" as possible, i.e. by prompting for paths
;; when appropriate, inserting correct pattern parameters based on synthdefs,
;; etc. If you don't care what something is named, you can enter just a period
;; (.) to automatically generate a name based on the
;; function that the `cl-patterns-name-generator' custom variable is
;; set to; by default it generates a name that is just random letters.

;;; Code:

(require 'cl-patterns-helpers)

(defcustom cl-patterns-bdef-default-directory nil
  "The directory that `bdef-skeleton''s filename completion should start from. If nil (the default), start from the current buffer's directory instead."
  :type '(choice directory (const nil)))

(defcustom cl-patterns-name-generator 'cl-patterns-generate-random-name
  "The function that is used to generate a default name for a pb or other named construct when the user supplies only a period."
  :type '(function))

(defun cl-patterns-read-name (prompt initial-input &optional default-value history)
  "Prompt the user for a name for the construct being generated by a skeleton. If the user enters just a period, a random name is generated with `cl-patterns-name-generator'."
  (let* ((history (or history 'cl-patterns-name-history))
         (res (read-string prompt initial-input history default-value)))
    (if (string= res ".")
        (funcall cl-patterns-name-generator)
      (cl-patterns-ensure-symbol-syntax res))))

(define-skeleton tempo-skeleton
  "Insert (tempo ...) with the current *clock* tempo."
  ""
  "(tempo " (number-to-string (or (cl-patterns-lisp-eval `(cl:* 60 (cl-patterns:tempo cl-patterns:*clock*)))
                                  110))
  _ "/60)")

(define-skeleton bdef-skeleton
  "Prompt for a file, then insert (bdef ...) that loads said file."
  ""
  "(bdef "
  (let* ((filename (read-file-name "bdef file? " cl-patterns-bdef-default-directory))
         (suggestion (concat ":" (cl-patterns-friendly-string (file-name-base filename))))
         (sym (cl-patterns-read-name "bdef name? (. to autogenerate) " suggestion (list (cl-patterns-increase-number-suffix (cl-patterns-guess-bdef))))))
    (concat sym " \"" (replace-regexp-in-string "\"" "\\\"" (abbreviate-file-name filename) t t) "\""))
  ")")

(define-skeleton pb-skeleton
  "Insert (pb ...), prompting for a name and an instrument."
  ""
  "(pb " (let* ((instrument (cl-patterns-select-instrument "pb instrument? "))
                (name (cl-patterns-read-name "pb name? (. to autogenerate) "
                                             nil
                                             (list (cl-patterns-increase-number-suffix (cl-patterns-guess-pdef))
                                                   (cl-patterns-increase-number-suffix instrument))))
                (args (cl-patterns-instrument-arguments instrument))
                (buf-arg (or (member "BUFFER" args)
                             (member "BUFNUM" args))))
           (concat name "\n  :instrument " instrument
                   (when buf-arg
                     (concat "\n  :" (downcase (car buf-arg)) " " (cl-patterns-guess-bdef))))) "
  :dur 1" _ "
  :pfindur 4)")

(define-skeleton pt-skeleton
  "Insert a basic ptrack pattern."
  ""
  "(pdef :" _ "
    (ptrack
     (list :note 0 :dur 1/4 :instrument :" (cl-patterns-guess-instrument) ")
     #T(- ;; 0
        -
        -
        -
        - ;; 4
        -
        -
        -
        - ;; 8
        -
        -
        -
        - ;; 12
        -
        -
        -
        )))")

(provide 'cl-patterns-skeletons)
;;; cl-patterns-skeletons.el ends here
