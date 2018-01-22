(in-package :cl-patterns)

;; FIX: `at' and `release' currently have to be defined here since clock.lisp uses them.

(defun release (node)
  (sc:release node))

(defun release-at (time node)
  (sc:at time
    (release node)))

(defun local-time-cl-collider (time)
  "Convert a local-time timestamp into the timestamp format used by cl-collider."
  (+ (local-time:timestamp-to-unix time) (* (local-time:timestamp-microsecond time) 1.0d-6)))

(defun get-synthdef-controls (name)
  (if (typep name 'node)
      (get-synthdef-controls (slot-value name 'name))
      (get-synthdef-metadata name :controls)))

(defun get-synthdef-control-names (name)
  (mapcar #'car (get-synthdef-controls name)))

(defgeneric has-gate-p (item))

(defmethod has-gate-p ((item t))
  (position :gate (get-synthdef-control-names item) :test #'string-equal))

(defmethod has-gate-p ((item sc::node))
  (has-gate-p (sc::name item)))

(defmethod has-gate-p ((item string))
  (has-gate-p (alexandria:make-keyword (string-upcase item))))

(defun generate-plist-for-synth (instrument event)
  "Generate a plist of parameters for a synth based off of the synth's arguments. Unlike `event-plist', this function doesn't include event keys that aren't also one of the synth's arguments."
  (let ((synth-params (remove-if (lambda (arg) ;; for parameters unspecified by the event, we fall back to the synth's defaults, NOT the event's.
                                   (multiple-value-bind (value key) (get-event-value event arg)
                                     (declare (ignore value))
                                     (eq key t)))
                                 (get-synthdef-control-names instrument))))
    (if synth-params
        (loop :for sparam :in synth-params
           :for val = (get-event-value event sparam)
           :if (or (eq :gate sparam)
                   (not (null val)))
           :append (list (alexandria:make-keyword sparam) (if (eq :gate sparam) 1 val)))
        (copy-list (event-plist event)))))

(defun convert-sc-objects-to-numbers (list)
  "Replace all SuperCollider objects in LIST (i.e. buses, buffers, etc) with their equivalent numbers."
  (mapcar (lambda (list-item)
            (typecase list-item
              (sc::buffer (sc:bufnum list-item))
              (sc::bus (sc:busnum list-item))
              (otherwise list-item)))
          list))

(defun get-proxys-node-id (name)
  "Get the current node ID of the proxy NAME, or NIL if it doesn't exist in cl-collider's node-proxy-table."
  (if (typep name 'sc::node)
      (get-proxys-node-id (alexandria:make-keyword (string-upcase (slot-value name 'sc::name))))
      (gethash name (sc::node-proxy-table sc::*s*))))

(defun play-sc (item &optional task)
  "Play ITEM on the SuperCollider sound server. TASK is an internal parameter used when this function is called from the clock."
  (unless (eq (get-event-value item :type) :rest)
    (let* ((inst (instrument item))
           (quant (alexandria:ensure-list (quant item)))
           (offset (if (> (length quant) 2)
                       (nth 2 quant)
                       0))
           (time (+ (or (raw-get-event-value item :latency) *latency*)
                    (or (raw-get-event-value item :unix-time-at-start) (sc:now))
                    offset))
           (params (convert-sc-objects-to-numbers (generate-plist-for-synth inst item))))
      (if (or (and (eq (get-event-value item :type) :mono)
                   (not (null task))) ;; if the user calls #'play manually, then we always start a note instead of checking if a node already exists.
              (typep inst 'sc::node))
          (let ((node (sc:at time
                        (cond ((not (null (slot-value task 'nodes)))
                               (apply #'sc:ctrl (car (slot-value task 'nodes)) params))
                              ((typep inst 'sc::node)
                               ;; redefining a proxy changes its Node's ID.
                               ;; thus if the user redefines a proxy, the Node object previously provided to the pbind will become inaccurate.
                               ;; thus we look up the proxy in the node-proxy-table to ensure we always have the correct ID.
                               (let ((node (or (get-proxys-node-id inst)
                                               inst)))
                                 (apply #'sc:ctrl node params)))
                              (t
                               (sc::synth inst params))))))
            (unless (or (typep inst 'sc::node)
                        (not (has-gate-p inst)))
              (if (< (legato item) 1)
                  (sc:at (+ time (dur-time (sustain item)))
                    (setf (slot-value task 'nodes) (list))
                    (release node))
                  (setf (slot-value task 'nodes) (list node)))))
          (let ((node (sc:at time
                        (sc::synth inst params))))
            (when (has-gate-p node)
              (sc:at (+ time (dur-time (sustain item)))
                (release node))))))))

(defun is-sc-event-p (event)
  (gethash (get-event-value event :instrument) sc::*synthdef-metadata*))

(defun timestamp-to-cl-collider (timestamp)
  "Convert a local-time timestamp to the format used by cl-collider."
  (+ (local-time:timestamp-to-unix timestamp) (* (local-time:nsec-of timestamp) 1.0d-9)))

(register-backend :cl-collider #'is-sc-event-p #'play-sc #'release #'release-at #'timestamp-to-cl-collider)

(setf *event-output-function* 'play-sc)
