(in-package #:org.shirakumo.fraf.vpetjam)

(define-shader-entity creature (part-parent object genetical)
  ((name :initform (generate-name 'creature))
   (texture :initform (// 'vpetjam 'creature))
   (move-time :initform 1.0 :accessor move-time)
   (spd :initform 0.0 :accessor spd)
   (random-direction :initform -1 :accessor random-direction))
  (:default-initargs :children '((:face  :uv (0 1) :pivot (0 0) :location (0 -10 0))
                                 (:hat   :uv (1 2) :pivot (0 0) :location (0  20 0)))))

(defmethod shared-initialize :after ((creature creature) slots &key)
  (setf (vx (uv-offset creature)) (gene creature :body))
  (setf (vx (uv-offset (part :face creature))) (gene creature :face))
  (setf (vx (uv-offset (part :hat creature))) (gene creature :hat))
  (setf (hue creature) (gene creature :hue))
  (setf (spd creature) (gene creature :speed)))

(defmethod apply-transforms progn ((creature creature))
  (scale-by 1.5 1.5 1))

(defmethod (setf direction) (dir (creature creature)))

(defmethod handle ((ev tick) (creature creature))
  (when (<= (height creature) 0)
    (let ((vel (velocity creature)))
      (case (hit-border creature)
        (:x (setf (vx vel) (* -1 (vx vel))))
        (:y (setf (vy vel) (* -1 (vy vel)))))
      (when (<= (decf (move-time creature) (dt ev)) 0.0)
        (let ((pol (cartesian->polar vel)))
          (v<- vel (polar->cartesian (vec
                                      (lerp (vx pol) (spd creature) 0.3)
                                      (+ (vy pol) (* (random-direction creature) (dt ev) 3))))))
        (when (<= (move-time creature) -0.5)
          (setf (random-direction creature) (float-sign (random* 0.0 1.0)))
          (setf (move-time creature) (random* 2.0 1.0))))
      (nv+ (frame-velocity creature) vel)))
  (setf (angle (part :hat creature))
        (float-sign (vx (velocity creature))
                    (* 0.5 (/ (vlength (velocity creature)) 10.0)))))
