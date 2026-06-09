import asyncio
from playwright.async_api import async_playwright

async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=True)
        page = await browser.new_page()
        
        console_logs = []
        page.on("console", lambda msg: console_logs.append(f"[{msg.type}] {msg.text}"))
        page.on("pageerror", lambda err: console_logs.append(f"[EXCEPTION] {err.message}"))
        
        print("Navigating to http://127.0.0.1:9003...")
        try:
            await page.goto("http://127.0.0.1:9003/", timeout=15000)
            await page.wait_for_timeout(5000) # wait 5s for app initialization
        except Exception as e:
            console_logs.append(f"[NAVIGATION ERROR] {e}")
            
        print("Saving screenshot to check_render.png...")
        await page.screenshot(path="check_render.png")
        
        print("\n--- Captured Console Logs ---")
        for log in console_logs:
            print(log)
        
        with open("console_logs.txt", "w", encoding="utf-8") as f:
            f.write("\n".join(console_logs))
            
        await browser.close()

if __name__ == "__main__":
    asyncio.run(main())
