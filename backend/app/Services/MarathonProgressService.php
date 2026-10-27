<?php

namespace App\Services;

use App\Models\CalorieProfile;
use App\Models\DailyTracker;
use App\Models\Marathon;
use App\Models\MarathonRegistration;
use Illuminate\Support\Carbon;

/**
 * Turns a runner's tracked steps during a marathon into kilometres and
 * marks them as a finisher (with a certificate number) once they reach
 * the distance before the marathon ends.
 */
class MarathonProgressService
{
    public const DEFAULT_STRIDE_METERS = 0.67;

    /**
     * @return array{steps: int, km: float, percent: float, finished: bool}
     */
    public function progress(MarathonRegistration $registration, ?Carbon $today = null): array
    {
        $marathon = $registration->marathon;
        $today = ($today ?? now())->copy()->startOfDay();
        $empty = ['steps' => 0, 'km' => 0.0, 'percent' => 0.0, 'finished' => $registration->finished_at !== null];

        if ($registration->status !== 'confirmed' || $today->lt($marathon->starts_at)) {
            return $empty;
        }

        $end = $today->lt($marathon->ends_at) ? $today : $marathon->ends_at;
        $steps = (int) DailyTracker::query()
            ->where('user_id', $registration->user_id)
            ->whereDate('date', '>=', $marathon->starts_at->toDateString())
            ->whereDate('date', '<=', $end->toDateString())
            ->sum('step_count');

        $km = round($steps * $this->strideMeters($registration->user_id) / 1000, 2);
        $finished = $registration->finished_at !== null || $km >= $marathon->distance_km;

        if ($finished && $registration->finished_at === null) {
            $registration->forceFill([
                'finished_at' => now(),
                'certificate_number' => $this->certificateNumber($marathon, $registration),
            ])->save();
        }

        return [
            'steps' => $steps,
            'km' => $km,
            'percent' => round(min(100, $km / max(0.01, $marathon->distance_km) * 100), 1),
            'finished' => $finished,
        ];
    }

    private function strideMeters(int|string $userId): float
    {
        $height = CalorieProfile::query()->where('user_id', $userId)->value('height_cm');

        return $height ? $height * 0.415 / 100 : self::DEFAULT_STRIDE_METERS;
    }

    private function certificateNumber(Marathon $marathon, MarathonRegistration $registration): string
    {
        return sprintf('IU-%04d-%05d', $marathon->id, $registration->bib_number ?? $registration->id);
    }
}
