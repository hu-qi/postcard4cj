#!/usr/bin/env python3
"""Resolve an official Cangjie SDK URL by inspecting the dynamic download page."""

from __future__ import annotations

import html
import json
import re
import sys
import time
from collections.abc import Iterable
from urllib.parse import urljoin

from selenium import webdriver
from selenium.common.exceptions import TimeoutException, WebDriverException
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait

URL_RE = re.compile(r"https?://[^\s\"'<>\\]+")


def normalized_text(value: str) -> str:
    return html.unescape(value).replace("\\/", "/").replace("\\u0026", "&")


def iter_urls(value: object) -> Iterable[str]:
    if isinstance(value, str):
        text = normalized_text(value)
        for match in URL_RE.finditer(text):
            yield match.group(0).rstrip(",);]")
    elif isinstance(value, dict):
        for nested in value.values():
            yield from iter_urls(nested)
    elif isinstance(value, list):
        for nested in value:
            yield from iter_urls(nested)


def choose_url(candidates: Iterable[str], filename: str) -> str | None:
    normalized: list[str] = []
    for candidate in candidates:
        candidate = normalized_text(candidate)
        if candidate.startswith("//"):
            candidate = "https:" + candidate
        normalized.append(candidate)
    for candidate in normalized:
        if filename in candidate:
            return candidate
    for candidate in normalized:
        lower = candidate.lower()
        if ".tar.gz" in lower and "cangjie" in lower:
            return candidate
    return None


def performance_messages(driver: webdriver.Chrome) -> list[dict[str, object]]:
    messages: list[dict[str, object]] = []
    for item in driver.get_log("performance"):
        try:
            messages.append(json.loads(item["message"])["message"])
        except (KeyError, TypeError, json.JSONDecodeError):
            continue
    return messages


def collect_network(messages: list[dict[str, object]]) -> tuple[list[str], list[str]]:
    candidates: list[str] = []
    response_ids: list[str] = []
    for message in messages:
        method = str(message.get("method", ""))
        params = message.get("params", {})
        if not isinstance(params, dict):
            continue
        if method == "Network.requestWillBeSent":
            request = params.get("request", {})
            if isinstance(request, dict) and isinstance(request.get("url"), str):
                candidates.append(request["url"])
        elif method == "Network.responseReceived":
            response = params.get("response", {})
            if isinstance(response, dict) and isinstance(response.get("url"), str):
                candidates.append(response["url"])
            request_id = params.get("requestId")
            if isinstance(request_id, str):
                response_ids.append(request_id)
        elif method == "Page.downloadWillBegin":
            url = params.get("url")
            if isinstance(url, str):
                candidates.append(url)
    return candidates, response_ids


def resolve(download_page: str, filename: str) -> str:
    options = webdriver.ChromeOptions()
    for argument in (
        "--headless=new",
        "--no-sandbox",
        "--disable-gpu",
        "--disable-dev-shm-usage",
        "--window-size=1600,1200",
        "--lang=zh-CN",
    ):
        options.add_argument(argument)
    options.set_capability("goog:loggingPrefs", {"performance": "ALL"})
    options.add_experimental_option(
        "prefs",
        {
            "download.prompt_for_download": False,
            "download_restrictions": 3,
            "safebrowsing.enabled": True,
        },
    )

    driver = webdriver.Chrome(options=options)
    try:
        driver.execute_cdp_cmd("Network.enable", {})
        for command in ("Browser.setDownloadBehavior", "Page.setDownloadBehavior"):
            try:
                driver.execute_cdp_cmd(command, {"behavior": "deny"})
            except WebDriverException:
                pass

        driver.get(download_page)
        package = WebDriverWait(driver, 25).until(
            EC.presence_of_element_located(
                (By.XPATH, f"//*[normalize-space(text())={json.dumps(filename)}]")
            )
        )
        container = package.find_element(
            By.XPATH,
            "./ancestor::div[contains(concat(' ', normalize-space(@class), ' '), ' ivu-row ')][1]",
        )

        messages = performance_messages(driver)
        vue_snapshot = driver.execute_script(
            """
            let element = arguments[0];
            while (element) {
              if (element.__vue__) {
                try { return JSON.stringify(element.__vue__.$data); }
                catch (error) { return String(error); }
              }
              element = element.parentElement;
            }
            return "";
            """,
            package,
        )

        download_controls = [
            element
            for element in container.find_elements(By.CSS_SELECTOR, ".down-btn")
            if element.is_displayed() and element.is_enabled()
        ]
        if not download_controls:
            raise RuntimeError(f"No .down-btn control found for {filename}")

        driver.execute_script(
            """
            window.__cangjieDownloadUrls = [];
            window.open = function(url) {
              window.__cangjieDownloadUrls.push(String(url));
              return null;
            };
            HTMLAnchorElement.prototype.click = function() {
              window.__cangjieDownloadUrls.push(String(this.href));
            };
            """
        )
        driver.execute_script("arguments[0].click();", download_controls[0])
        time.sleep(2.0)

        confirmation_words = {
            "同意", "确认", "继续", "下载",
            "agree", "confirm", "continue", "download",
        }
        for element in driver.find_elements(By.XPATH, "//button | //a | //*[@role='button']"):
            if (
                element.text.strip().lower() in confirmation_words
                and element.is_displayed()
                and element.is_enabled()
                and element not in download_controls
            ):
                driver.execute_script("arguments[0].click();", element)
                time.sleep(2.0)
                break

        messages.extend(performance_messages(driver))
        candidates, response_ids = collect_network(messages)

        recorded = driver.execute_script("return window.__cangjieDownloadUrls || [];")
        if isinstance(recorded, list):
            candidates.extend(str(value) for value in recorded)
        if isinstance(vue_snapshot, str):
            candidates.extend(iter_urls(vue_snapshot))

        direct = choose_url(candidates, filename)
        if direct:
            return urljoin(download_page, direct)

        body_candidates: list[str] = []
        filename_contexts: list[str] = []
        for request_id in response_ids:
            try:
                body = driver.execute_cdp_cmd(
                    "Network.getResponseBody", {"requestId": request_id}
                ).get("body", "")
            except WebDriverException:
                continue
            if not isinstance(body, str):
                continue
            body = normalized_text(body)
            body_candidates.extend(iter_urls(body))
            position = body.find(filename)
            if position >= 0:
                filename_contexts.append(body[max(0, position - 500): position + 1500])

        direct = choose_url(body_candidates, filename)
        if direct:
            return urljoin(download_page, direct)

        raise RuntimeError(
            "Official SDK data did not expose a package URL. Diagnostics: "
            + json.dumps(
                {
                    "package_row": container.get_attribute("outerHTML")[:4000],
                    "network_urls": candidates[-100:],
                    "vue_data": str(vue_snapshot)[:6000],
                    "filename_contexts": filename_contexts[:5],
                    "page_url": driver.current_url,
                },
                ensure_ascii=False,
            )
        )
    finally:
        driver.quit()


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: resolve-cangjie-sdk-url.py DOWNLOAD_PAGE SDK_FILENAME", file=sys.stderr)
        return 2
    try:
        print(resolve(sys.argv[1], sys.argv[2]))
        return 0
    except (RuntimeError, TimeoutException, WebDriverException) as error:
        print(f"Unable to resolve official Cangjie SDK URL: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
