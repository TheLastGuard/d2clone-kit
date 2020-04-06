(in-package :d2clone-kit)


(defclass player-system (system)
  ((name :initform 'player)
   (mouse-pressed :initform nil)
   (entity :initform -1)
   (debug-entity :initform -1))
  (:documentation "Handles player character."))

(defcomponent player player)

(defmethod make-component ((system player-system) entity &rest parameters)
  (declare (ignore parameters))
  (setf (slot-value system 'entity) entity)
  (with-system-config-options ((debug-cursor))
    (when debug-cursor
      (let ((debug-entity (make-entity)))
        (setf (slot-value system 'debug-entity) debug-entity)
        (make-component (system-ref 'debug) debug-entity :order 2000d0)))))

(declaim (inline player-entity))
(defun player-entity ()
  "Returns current player entity."
  (slot-value (system-ref 'player) 'entity))

(declaim
 (inline mouse-position)
 (ftype (function (&optional (or cffi:foreign-pointer null)) (values fixnum fixnum)) mouse-position))
(defun mouse-position (&optional (event nil))
  "Get current mouse cursor coordinates using liballegro mouse event EVENT or by calling [al_get_mouse_state](https://liballeg.org/a5docs/trunk/mouse.html#al_get_mouse_state)."
  (macrolet
      ((mouse-position-values (type struct)
         `(cffi:with-foreign-slots ((al::x al::y) ,struct (:struct ,type))
            (values al::x al::y))))
    (if event
        (mouse-position-values al:mouse-event event)
        (al:with-current-mouse-state state
          (mouse-position-values al:mouse-state state)))))

(defun target-player (&optional (mouse-event nil))
  "Set new player character target according to MOUSE-EVENT or current mouse cursor position."
  (multiple-value-bind (x y) (mouse-position mouse-event)
    (multiple-value-bind (new-screen-x new-screen-y)
        (viewport->absolute x y)
      (multiple-value-bind (new-x new-y)
          (screen->map new-screen-x new-screen-y)
        (set-character-target (player-entity) new-x new-y)))))

(defhandler player-system allegro-event (event event-type)
  :filter '(eq event-type :mouse-button-down)
  (let ((allegro-event (slot-value event 'event)))
    (when (= 1 (cffi:foreign-slot-value allegro-event '(:struct al:mouse-event) 'al::button))
      (target-player allegro-event)
      (setf (slot-value system 'mouse-pressed) t))))

(defhandler player-system allegro-event (event event-type)
  :filter '(eq event-type :mouse-button-up)
  (let ((allegro-event (slot-value event 'event)))
    (when (= 1 (cffi:foreign-slot-value allegro-event '(:struct al:mouse-event) 'al::button))
      (setf (slot-value system 'mouse-pressed) nil))))

(defmethod system-update ((system player-system) dt)
  (when (slot-value system 'mouse-pressed)
    (target-player)))

(defmethod system-draw ((system player-system) renderer)
  (with-system-config-options ((debug-cursor))
    (when debug-cursor
      (multiple-value-bind (map-x map-y)
          (multiple-value-call #'screen->map
            (multiple-value-call #'viewport->absolute
              (mouse-position)))
        (multiple-value-bind (x y)
            (multiple-value-call #'absolute->viewport
              (map->screen (coerce (floor map-x) 'double-float)
                           (coerce (floor map-y) 'double-float)))
          (add-debug-rectangle
           (slot-value system 'debug-entity)
           x y *tile-width* *tile-height* debug-cursor))))))
