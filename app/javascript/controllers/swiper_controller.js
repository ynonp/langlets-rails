import { Controller } from "@hotwired/stimulus"
import { Swiper } from "swiper"

export default class extends Controller {
  static targets = ["container"]
  static values = { 
    slidesPerView: { type: Number, default: 1 },
    spaceBetween: { type: Number, default: 24 },
    freeMode: { type: Boolean, default: true }
  }

  connect() {
    this.initSwiper()
  }

  disconnect() {
    if (this.swiper) {
      this.swiper.destroy()
    }
  }

  initSwiper() {
    const config = {
      slidesPerView: "auto",
      spaceBetween: this.spaceBetweenValue,
      freeMode: this.freeModeValue,
      grabCursor: true,
      breakpoints: {
        640: {
          slidesPerView: "auto",
          spaceBetween: this.spaceBetweenValue
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

    this.swiper = new Swiper(this.containerTarget, config)
  }
}
