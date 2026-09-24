(() => {
  const header = document.querySelector(".header");
  const menuBtn = document.querySelector(".menu-btn");
  const menu = document.querySelector(".menu");
  const yearEls = document.querySelectorAll("[data-year]");
  const isInner = document.body.classList.contains("page");

  yearEls.forEach((el) => {
    el.textContent = String(new Date().getFullYear());
  });

  const onScroll = () => {
    if (!header || isInner || header.classList.contains("header--solid")) return;
    const pastHero = window.scrollY > Math.min(window.innerHeight * 0.55, 420);
    header.classList.toggle(
      "is-on",
      pastHero || (menu && menu.classList.contains("is-open"))
    );
  };

  onScroll();
  window.addEventListener("scroll", onScroll, { passive: true });
  window.addEventListener("resize", onScroll);

  if (menuBtn && menu) {
    const setOpen = (open) => {
      menuBtn.setAttribute("aria-expanded", String(open));
      menuBtn.setAttribute("aria-label", open ? "Close menu" : "Open menu");
      menu.classList.toggle("is-open", open);
      document.body.style.overflow = open ? "hidden" : "";
      if (!isInner) {
        header?.classList.toggle("is-on", open || window.scrollY > 80);
      }
    };

    menuBtn.addEventListener("click", () => {
      setOpen(menuBtn.getAttribute("aria-expanded") !== "true");
    });

    menu.querySelectorAll("a").forEach((a) => {
      a.addEventListener("click", () => setOpen(false));
    });

    window.addEventListener("keydown", (e) => {
      if (e.key === "Escape") setOpen(false);
    });
  }

  const targets = document.querySelectorAll(
    ".device, .band__head, .flow__item, .gallery__item, .privacy__copy, .privacy__panel, .wrap--get, .wrap--split, .faq, .wrap--disclaimer"
  );

  targets.forEach((el) => el.classList.add("reveal"));

  if ("IntersectionObserver" in window) {
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (!entry.isIntersecting) return;
          entry.target.classList.add("is-in");
          io.unobserve(entry.target);
        });
      },
      { threshold: 0.14, rootMargin: "0px 0px -6% 0px" }
    );
    targets.forEach((el) => io.observe(el));
  } else {
    targets.forEach((el) => el.classList.add("is-in"));
  }

  const form = document.getElementById("enquiry-form");
  const status = document.getElementById("form-status");

  if (form && status) {
    form.addEventListener("submit", (e) => {
      e.preventDefault();

      if (!form.checkValidity()) {
        status.hidden = false;
        status.classList.add("is-error");
        status.textContent = "Please complete all required fields.";
        form.reportValidity();
        return;
      }

      const data = new FormData(form);
      const subject = encodeURIComponent(`[VitaNet] ${data.get("topic")} enquiry`);
      const body = encodeURIComponent(
        `Name: ${data.get("name")}\nEmail: ${data.get("email")}\nTopic: ${data.get("topic")}\n\n${data.get("message")}`
      );

      status.hidden = false;
      status.classList.remove("is-error");
      status.textContent = "Opening your email client…";

      window.location.href = `mailto:hello@vitanet.app?subject=${subject}&body=${body}`;

      window.setTimeout(() => {
        status.textContent =
          "If your email app did not open, write to hello@vitanet.app directly.";
      }, 1200);
    });
  }
})();
