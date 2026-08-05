require "term-spinner"

# Crystal 1.21 released execution contexts and made them the default: the
# runtime now starts a `Fiber::ExecutionContext::Parallel` context, whose
# scheduler rejects `spawn(same_thread: true)` with
#
#   Fiber::ExecutionContext::Parallel::Scheduler#spawn doesn't support same_thread:true
#
# term-spinner still spawns its animation fiber with `same_thread: true`, so
# every `auto_spin` (e.g. `bld login`) aborts when the CLI is compiled with
# Crystal >= 1.21. Redefine `auto_spin` with a plain `spawn`, which behaves
# identically on every Crystal version we support. Drop this file once
# term-spinner ships the fix upstream.
module Term
  class Spinner
    def auto_spin
      start
      sleep_time = @interval

      spin
      spawn do
        sleep(sleep_time)
        until stopped?
          sleep(sleep_time)
          spin unless paused?
        end
      end
    ensure
      if @hide_cursor
        write(Term::Cursor.show, false)
      end
    end
  end
end
