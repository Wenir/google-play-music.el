;;; google-play-music.el --- Google Play Music Desktop Player Control              -*- lexical-binding: t; -*-

;; Copyright (C) 2016  A.I.

;; Author: A.I. <merrick@luois.me>
;; Keywords: extensions
;; Version: 0.1

;;; Code:
(require 'websocket)
(require 'json)

(defvar google-play-music-mode-line-text "Not Connected")

(defvar google-play-music--playing-symbol "ᐅ")
(defvar google-play-music--paused-symbol "||")
(defvar google-play-music--current-track nil)
(defvar google-play-music--current-state google-play-music--paused-symbol)

(defvar google-play-music--ws nil)

(defun connectp()
  (if google-play-music--ws
      (websocket-openp google-play-music--ws)
    nil))

(defun google-play-music--update-mode-line()
  "update mode line by adding play state and currently playing track"
  (setq google-play-music-mode-line-text
        (concat google-play-music--current-state " " google-play-music--current-track)))

(defun google-play-music--update-state(state)
  "save currently playing state"
  (setq google-play-music--current-state
        (if (eq state :json-false)
            google-play-music--paused-symbol
          google-play-music--playing-symbol))
  (google-play-music--update-mode-line))

(defun google-play-music--update-track(track)
  "save currently playing track"
  (lexical-let* ((title (plist-get track :title))
                 (artist (plist-get track :artist)))
    (setq google-play-music--current-track
          (concat title "-" artist))
    (google-play-music--update-mode-line)))

(defun google-play-music--connection-change(resp)
  "handle connection auth"
  (if (string= resp "CODE_REQUIRED")
      (let ((code (read-string "Enter Code: ")))
        (google-play-music--connect code))
    (google-play-music--connect resp)))


(defun google-play-music--dispatch-message(msg)
  "dispatch messages from websocket server"
  (setq jmsg (let ((json-object-type 'plist))
               (json-read-from-string msg)))
  (let ((channel (plist-get jmsg :channel))
        (payload (plist-get jmsg :payload)))
    (cond ((string= channel "time") nil)
          ((string= channel "playState") (google-play-music--update-state payload))
          ((string= channel "connect") (google-play-music--connection-change payload))
          ((string= channel "track") (google-play-music--update-track payload)))))

(defun google-play-music--connect(&optional arg)
  "send connect request"
    (let ((msg '(:namespace "connect" :method "connect")))
      (let* ((param (if (numberp arg) (number-to-string arg) arg))
             (parg (if param
                       (plist-put msg :arguments `("google-play-music.el", param))
                     (plist-put msg :arguments '("google-play-music.el")))))
        (websocket-send-text google-play-music--ws (json-encode parg)))))

(defun google-play-music-connect()
  "make connection to google play music desktop player"
  (interactive)
  (unless (connectp)
    (setq google-play-music--ws
          (websocket-open
           "ws://localhost:5672"
           :on-message (lambda (_websocket frame)
                         (google-play-music--dispatch-message (websocket-frame-text frame)))))))

(defun google-play-music-play-pause()
  "Play Pause"
  (interactive)
  (let ((msg '(:namespace "playback" :method "playPause" :requestID 1)))
    (websocket-send-text google-play-music--ws (json-encode msg))))

(defun google-play-music-next()
  "Play next song"
  (interactive)
  (let ((msg '(:namespace "playback" :method "forward" :requestID 1)))
    (websocket-send-text google-play-music--ws (json-encode msg))))

(defun google-play-music-previous()
  "Rewind to start or previous song"
  (interactive)
  (let ((msg '(:namespace "playback" :method "rewind" :requestID 1)))
    (websocket-send-text google-play-music--ws (json-encode msg))))

(defun google-play-music--set-rating (rating)
  (let ((msg (list :namespace "rating" :method "setRating" :arguments (vector rating))))
	(websocket-send-text google-play-music--ws (json-encode msg))))

(defun google-play-music-thumbs-up()
  "Set the rating to 5"
  (interactive)
  (google-play-music--set-rating "5"))

(defun google-play-music-thumbs-down()
  "Set the rating to 1"
  (interactive)
  (google-play-music--set-rating "1"))

(defun google-play-music-reset-rating ()
  "Set the rating to 0"
  (interactive)
  (let ((msg (list :namespace "rating" :method "resetRating" :requestID 1)))
	(websocket-send-text google-play-music--ws (json-encode msg))))

(provide 'google-play-music)
;;; google-play-music.el ends here
