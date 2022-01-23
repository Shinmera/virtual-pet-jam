(in-package #:org.shirakumo.fraf.vpetjam)

(defclass ui (org.shirakumo.fraf.trial.alloy:ui
              org.shirakumo.alloy:fixed-scaling-ui
              org.shirakumo.alloy.renderers.simple.presentations:default-look-and-feel)
  ((alloy:target-resolution :initform (alloy:px-size 1280 720))
   (alloy:scales :initform '((3840 T 2.0)
                             (2800 T 1.5)
                             (1920 T 1.25)
                             (1280 T 1.0)
                             (1000 T 0.8)
                             (T T 0.5)))))

(defmethod org.shirakumo.alloy.renderers.opengl.msdf:fontcache-directory ((ui ui))
  (pool-path 'vpetjam "font-cache/"))

(define-shader-pass ui-pass (ui)
  ((name :initform 'ui-pass)
   (panels :initform NIL :accessor panels)
   (color :port-type output :attachment :color-attachment0)
   (depth :port-type output :attachment :depth-stencil-attachment)))

(defmethod initialize-instance :after ((pass ui-pass) &key)
  (make-instance 'alloy:fullscreen-layout :layout-parent (alloy:layout-tree pass))
  (make-instance 'alloy:focus-list :focus-parent (alloy:focus-tree pass)))

(defmethod render :before ((pass ui-pass) target)
  (gl:enable :depth-test)
  (gl:clear-color 0 0 0 0))

(defmethod render :after ((pass ui-pass) target)
  (gl:disable :depth-test))

(defmethod handle :around ((ev event) (pass ui-pass))
  (unless (call-next-method)
    (dolist (panel (panels pass))
      (handle ev panel)
      (when (typep panel 'pausing-panel)
        (return)))))

(defmethod handle ((ev accept) (pass ui-pass))
  (alloy:handle (load-time-value (make-instance 'alloy:activate)) pass))

(defmethod handle ((ev back) (pass ui-pass))
  (alloy:handle (load-time-value (make-instance 'alloy:exit)) pass))

(defmethod handle ((ev next) (pass ui-pass))
  (alloy:handle (load-time-value (make-instance 'alloy:focus-next)) pass))

(defmethod handle ((ev previous) (pass ui-pass))
  (alloy:handle (load-time-value (make-instance 'alloy:focus-prev)) pass))

(defmethod handle ((ev text-entered) (pass ui-pass))
  (or (call-next-method)
      (process-cheats (text ev))))

(defmethod alloy:focus-next :around ((chain alloy:focus-chain))
  (let ((focused (alloy:focused chain)))
    (call-next-method)
    #++
    (if (eql focused (alloy:focused chain))
        (harmony:play (// 'sound 'ui-no-more-to-focus) :reset T)
        (harmony:play (// 'sound 'ui-focus-next) :reset T))))

(defmethod alloy:focus-prev :around ((chain alloy:focus-chain))
  (let ((focused (alloy:focused chain)))
    (call-next-method)
    #++
    (if (eql focused (alloy:focused chain))
        (harmony:play (// 'sound 'ui-no-more-to-focus) :reset T)
        (harmony:play (// 'sound 'ui-focus-next) :reset T))))

(defmethod alloy:notice-focus :before (thing (chain alloy:focus-chain))
  #++
  (when (and (eql :strong (alloy:focus chain))
             (not (eq thing (alloy:focused chain))))
    (harmony:play (// 'sound 'ui-focus-next) :reset T)))

(defmethod stage ((pass ui-pass) (area staging-area))
  (call-next-method)
  (dolist (panel (panels pass))
    (stage panel area))
  (dolist (sound '(buy combiner pick plant sell shop spawn error throw))
    (stage (// 'sound sound) area))
  (stage (// 'music 'main) area)
  (stage (simple:request-font pass (setting :display :font)) area)
  (stage (simple:request-font pass "PromptFont") area)
  (stage (simple:request-font pass "Brands") area)
  (stage (framebuffer pass) area))

(defmethod compile-to-pass (object (pass ui-pass)))
(defmethod compile-into-pass (object container (pass ui-pass)))
(defmethod remove-from-pass (object (pass ui-pass)))

;; KLUDGE: No idea why this is necessary, fuck me.
(defmethod simple:request-font :around ((pass ui-pass) font &key)
  (let ((font (call-next-method)))
    (unless (and (alloy:allocated-p font)
                 (allocated-p (org.shirakumo.alloy.renderers.opengl.msdf:atlas font)))
      (trial:commit font (loader +main+) :unload NIL))
    font))

(defun find-panel (panel-type)
  (loop for panel in (panels (unit 'ui-pass T))
        do (when (typep panel panel-type)
             (return panel))))

(defun toggle-panel (panel-type &rest initargs)
  (let ((panel (find-panel panel-type)))
    (if panel
        (hide panel)
        (show (apply #'make-instance panel-type initargs)))))

(defun show-panel (panel-type &rest initargs)
  (let ((panel (find-panel panel-type)))
    (unless panel
      (show (apply #'make-instance panel-type initargs)))))

(defun hide-panel (panel-type)
  (if (eq T panel-type)
      (loop for panel = (first (panels (unit 'ui-pass T)))
            while panel do (hide panel))
      (let ((panel (find-panel panel-type)))
        (when panel
          (hide panel)))))

(defclass panel (alloy:structure)
  ((active-p :initform NIL :accessor active-p)))

(defmethod handle ((ev event) (panel panel)))

(defmethod shown-p ((panel panel))
  (slot-boundp (alloy:layout-element panel) 'alloy:layout-parent))

(defmethod show ((panel panel) &key ui)
  (when *context*
    ;; First stage and load
    (trial:commit panel (loader +main+) :unload NIL))
  ;; Then attach to the UI
  (let ((ui (or ui (unit 'ui-pass T))))
    (when (alloy:focus-element panel)
      (dolist (panel (panels ui))
        (setf (active-p panel) NIL)))
    (alloy:enter panel (alloy:root (alloy:layout-tree ui)))
    (alloy:register panel ui)
    (when (alloy:focus-element panel)
      (alloy:enter panel (alloy:root (alloy:focus-tree ui)))
      (setf (alloy:focus (alloy:focus-element panel)) :strong))
    (push panel (panels ui))
    (setf (active-p panel) T)
    panel))

(defmethod hide ((panel panel))
  (let ((ui (unit 'ui-pass T)))
    (when (alloy:layout-tree (alloy:layout-element panel))
      (alloy:leave panel (alloy:root (alloy:layout-tree ui)))
      (alloy:leave panel (alloy:root (alloy:focus-tree ui)))
      (setf (panels ui) (remove panel (panels ui))))
    (setf (active-p panel) NIL)
    (dolist (panel (panels ui))
      (setf (active-p panel) T)
      (when (alloy:focus-element panel)
        (setf (alloy:focus (alloy:focus-element panel)) :strong)
        (return)))
    panel))

(defclass fullscreen-panel (panel)
  ())

(defmethod show :after ((panel fullscreen-panel) &key)
  ;; Hide prompts
  (let ((els ()))
    (alloy:do-elements (el (alloy:popups (alloy:layout-tree (unit 'ui-pass T))))
      (when (typep el '(or prompt panel))
        (push el els)))
    (mapc #'hide els)))

(defclass menuing-panel (fullscreen-panel)
  ())

(defmethod (setf active-p) :after (value (panel menuing-panel))
  (if value
      (setf (active-p (action-set 'in-menu)) T)
      (setf (active-p (action-set 'in-game)) T)))

(defclass pausing-panel (fullscreen-panel)
  ())

(defmethod show :after ((panel pausing-panel) &key)
  ;; Clear pending events to avoid spurious inputs
  (discard-events +world+)
  (clear-retained))

(defmethod hide :after ((panel pausing-panel))
  ;; Clear pending events to avoid spurious inputs
  (discard-events +world+)
  (clear-retained))

(defclass eating-constraint-layout (org.shirakumo.alloy.layouts.constraint:layout)
  ())

(defmethod alloy:handle ((ev alloy:pointer-event) (focus eating-constraint-layout))
  (restart-case
      (call-next-method)
    (alloy:decline ()
      T)))

(presentations:define-realization (ui eating-constraint-layout)
  ((:bg simple:rectangle)
   (alloy:margins)
   :pattern (colored:color 1 1 1 0.75)))

(defclass button (alloy:button*)
  ())

(presentations:define-realization (ui button)
  ((:background simple:rectangle)
   (alloy:margins))
  ((border simple:rectangle)
   (alloy:margins)
   :line-width (alloy:un 1))
  ((:label simple:text)
   (alloy:margins 5 10 10 5)
   alloy:text
   :font (setting :display :font)
   :halign :middle
   :valign :middle))

(presentations:define-update (ui button)
  (:background
   :pattern (if alloy:focus colors:white (colored:color 1 1 1 0.1)))
  (border
   :pattern (if alloy:focus colors:transparent colors:white))
  (:label
   :size (alloy:un 20)
   :pattern colors:black))

(presentations:define-animated-shapes button
  (:background (simple:pattern :duration 0.2))
  (border (simple:pattern :duration 0.3)))

(defclass label (alloy:label*)
  ())

(presentations:define-realization (ui label)
  ((:label simple:text)
   (alloy:margins 0)
   alloy:text
   :font (setting :display :font)
   :wrap T
   :size (alloy:un 20)
   :halign :start
   :valign :middle))

(presentations:define-update (ui label)
  (:label
   :pattern colors:white))

(presentations:define-realization (ui alloy:checkbox)
  ((:border simple:rectangle)
   (alloy:extent 0 0 (alloy:ph 1) (alloy:ph 1))
   :pattern colors:white
   :line-width (alloy:un 2))
  ((:check simple:rectangle)
   (alloy:extent (alloy:ph 0.15) (alloy:ph 0.15) (alloy:ph 0.7) (alloy:ph 0.7))
   :hidden-p (not (alloy:active-p alloy:renderable))
   :pattern colors:orange))

(presentations:define-update (ui alloy:checkbox)
  (:border
   :hidden-p NIL
   :pattern (if alloy:focus
                (colored:color 0.9 0.9 0.9)
                colors:gray))
  (:check
   :pattern (if alloy:focus (colored:color 0.9 0.9 0.9) colors:orange)
   :hidden-p (not (alloy:active-p alloy:renderable))))

(presentations:define-realization (ui alloy:slider)
  ((:background simple:rectangle)
   (ecase (alloy:orientation alloy:renderable)
     (:horizontal (alloy:extent 0 (alloy:ph 0.4) (alloy:pw) (alloy:ph 0.2)))
     (:vertical (alloy:extent (alloy:pw 0.4) 0 (alloy:pw 0.2) (alloy:ph)))))
  ((:border simple:rectangle)
   (alloy:margins -3)
   :line-width (alloy:un 1))
  ((:handle simple:rectangle)
   (ecase (alloy:orientation alloy:renderable)
     (:horizontal (alloy:extent -5 0 10 (alloy:ph)))
     (:vertical (alloy:extent 0 -5 (alloy:pw) 10))))
  ((:display simple:text)
   (alloy:margins)
   (format NIL "~,2f" alloy:value)
   :pattern colors:white
   :font (setting :display :font)
   :halign :middle
   :valign :middle))

(presentations:define-update (ui alloy:slider)
  (:handle
   :pattern (case alloy:focus
              (:strong colors:white)
              (T colors:orange)))
  (:display
   :text (format NIL "~,2f" alloy:value)))
