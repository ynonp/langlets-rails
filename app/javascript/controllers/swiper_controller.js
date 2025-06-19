import { Controller } from "@hotwired/stimulus"
import { Swiper } from "swiper"
import { FreeMode } from "swiper/modules"

export default class extends Controller {
  static targets = ["container"]
  static values = { 
    slidesPerView: { type: Number, default: 1 },
    spaceBetween: { type: Number, default: 24 },
    freeMode: { type: Boolean, default: true }
  }

  connect() {
    // Add a small delay to ensure DOM is ready
    setTimeout(() => {
      this.initSwiper()
    }, 100)
  }

  disconnect() {
    if (this.swiper) {
      this.swiper.destroy(true, true)
      this.swiper = null
    }
  }

  initSwiper() {
    if (!this.containerTarget) return
    
    // Configure Swiper modules
    Swiper.use([FreeMode])
    
    const config = {
      slidesPerView: "auto",
      spaceBetween: this.spaceBetweenValue,
      freeMode: {
        enabled: this.freeModeValue,
        sticky: false,
      },
      grabCursor: true,
      touchRatio: 1,
      touchAngle: 45,
      longSwipesRatio: 0.5,
      longSwipesMs: 300,
      followFinger: true,
      mousewheel: {
        forceToAxis: true,
      },
      breakpoints: {
        320: {
          slidesPerView: "auto",
          spaceBetween: 16,
          freeMode: {
            enabled: true,
            sticky: false,
          }
        },
        640: {
          slidesPerView: "auto",
          spaceBetween: 20
        },
        768: {
          slidesPerView: "auto", 
          spaceBetween: this.spaceBetweenValue
        },
        1024: {
          slidesPerView: "auto",
          spaceBetween: this.spaceBetweenValue
        }
      }
    }

    try {
      this.swiper = new Swiper(this.containerTarget, config)      
    } catch (error) {
      console.error("Swiper initialization error:", error)
    }
  }
}
