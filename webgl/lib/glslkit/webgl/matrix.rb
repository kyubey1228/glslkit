# frozen_string_literal: true

module Glslkit
  module WebGL
    module Matrix
      module_function

      def identity!(out)
        16.times { |i| out[i] = 0.0 }
        out[0] = out[5] = out[10] = out[15] = 1.0
        out
      end

      def rotation_z!(out, radians)
        cosine = Math.cos(radians)
        sine = Math.sin(radians)
        identity!(out)
        out[0] = cosine
        out[1] = sine
        out[4] = -sine
        out[5] = cosine
        out
      end

      def rotation_y!(out, radians)
        cosine = Math.cos(radians)
        sine = Math.sin(radians)
        identity!(out)
        out[0] = cosine
        out[2] = -sine
        out[8] = sine
        out[10] = cosine
        out
      end

      def translation!(out, x, y, z)
        identity!(out)
        out[12] = x
        out[13] = y
        out[14] = z
        out
      end

      def multiply!(out, left, right)
        4.times do |column|
          offset = column * 4
          r0 = right[offset].to_f
          r1 = right[offset + 1].to_f
          r2 = right[offset + 2].to_f
          r3 = right[offset + 3].to_f
          out[offset] = left[0].to_f * r0 + left[4].to_f * r1 + left[8].to_f * r2 + left[12].to_f * r3
          out[offset + 1] = left[1].to_f * r0 + left[5].to_f * r1 + left[9].to_f * r2 + left[13].to_f * r3
          out[offset + 2] = left[2].to_f * r0 + left[6].to_f * r1 + left[10].to_f * r2 + left[14].to_f * r3
          out[offset + 3] = left[3].to_f * r0 + left[7].to_f * r1 + left[11].to_f * r2 + left[15].to_f * r3
        end
        out
      end

      def perspective!(out, fovy, aspect, near, far)
        f = 1.0 / Math.tan(fovy / 2.0)
        16.times { |i| out[i] = 0.0 }
        out[0] = f / aspect
        out[5] = f
        out[11] = -1.0
        if far
          nf = 1.0 / (near - far)
          out[10] = (far + near) * nf
          out[14] = 2.0 * far * near * nf
        else
          out[10] = -1.0
          out[14] = -2.0 * near
        end
        out
      end
    end
  end
end
