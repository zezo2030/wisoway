// Ratings List Page: Admin rating management
// Displays all ratings with delete action for abusive reviews

import { useState } from "react"
import { useSearchParams } from "react-router-dom"
import { useQuery, useMutation, useQueryClient } from "@tanstack/react-query"
import { getRatings, deleteRating } from "@/api/admin"
import { DataTable, type Column } from "@/components/data-table"
import { ConfirmDialog } from "@/components/confirm-dialog"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader } from "@/components/ui/card"
import { QUERY_KEYS, DASHBOARD_REFRESH_INTERVAL } from "@/lib/constants"
import { formatDate } from "@/lib/utils"
import type { Rating, UserSummary } from "@/types/models"
import { Star, Trash2, AlertCircle } from "lucide-react"
import { toast } from "sonner"

function isPopulatedUser(val: string | UserSummary): val is UserSummary {
    return typeof val === "object" && val !== null && "name" in val
}

function StarDisplay({ rating }: { rating: number }) {
    return (
        <div className="flex items-center gap-0.5">
            {[1, 2, 3, 4, 5].map((star) => (
                <Star
                    key={star}
                    className={`h-4 w-4 ${star <= rating ? "fill-amber-400 text-amber-400" : "text-muted-foreground/30"}`}
                />
            ))}
            <span className="ml-1.5 text-sm font-bold text-foreground">{rating}</span>
        </div>
    )
}

export default function RatingsListPage() {
    const [searchParams, setSearchParams] = useSearchParams()
    const queryClient = useQueryClient()
    const page = parseInt(searchParams.get("page") || "1", 10)
    const limit = 20

    const [confirmDialog, setConfirmDialog] = useState<{
        open: boolean
        rating: Rating | null
    }>({
        open: false,
        rating: null,
    })

    const { data, isLoading, error } = useQuery({
        queryKey: [QUERY_KEYS.ADMIN.RATINGS, { page, limit }],
        queryFn: () => getRatings({ page, limit }),
        refetchInterval: DASHBOARD_REFRESH_INTERVAL,
    })

    const deleteMutation = useMutation({
        mutationFn: (ratingId: string) => deleteRating(ratingId),
        onSuccess: () => {
            queryClient.invalidateQueries({ queryKey: [QUERY_KEYS.ADMIN.RATINGS] })
            toast.success("Rating deleted successfully")
            setConfirmDialog({ open: false, rating: null })
        },
        onError: () => {
            toast.error("Failed to delete rating")
        },
    })

    const handlePageChange = (newPage: number) => {
        const newParams = new URLSearchParams(searchParams)
        newParams.set("page", String(newPage))
        setSearchParams(newParams)
    }

    const columns: Column<Rating>[] = [
        {
            key: "from",
            header: "From",
            cell: (rating) => (
                <div className="flex items-center gap-3 py-1">
                    {isPopulatedUser(rating.fromUserId) ? (
                        <>
                            <div className="flex h-9 w-9 items-center justify-center rounded-full bg-emerald-500/10 text-emerald-600 font-bold text-sm shadow-sm border border-emerald-500/20 flex-shrink-0">
                                {rating.fromUserId.name.charAt(0).toUpperCase()}
                            </div>
                            <div>
                                <div className="font-semibold text-foreground">{rating.fromUserId.name}</div>
                                <div className="text-xs font-medium text-muted-foreground">{rating.fromUserId.email}</div>
                            </div>
                        </>
                    ) : (
                        <span className="text-muted-foreground font-mono text-xs">ID: {rating.fromUserId}</span>
                    )}
                </div>
            ),
        },
        {
            key: "to",
            header: "To",
            cell: (rating) => (
                <div className="flex items-center gap-3 py-1">
                    {isPopulatedUser(rating.toUserId) ? (
                        <>
                            <div className="flex h-9 w-9 items-center justify-center rounded-full bg-blue-500/10 text-blue-600 font-bold text-sm shadow-sm border border-blue-500/20 flex-shrink-0">
                                {rating.toUserId.name.charAt(0).toUpperCase()}
                            </div>
                            <div>
                                <div className="font-semibold text-foreground">{rating.toUserId.name}</div>
                                <div className="text-xs font-medium text-muted-foreground">{rating.toUserId.email}</div>
                            </div>
                        </>
                    ) : (
                        <span className="text-muted-foreground font-mono text-xs">ID: {rating.toUserId}</span>
                    )}
                </div>
            ),
        },
        {
            key: "rating",
            header: "Rating",
            cell: (rating) => <StarDisplay rating={rating.rating} />,
        },
        {
            key: "comment",
            header: "Comment",
            cell: (rating) => (
                <div className="max-w-[300px] truncate text-sm text-muted-foreground">
                    {rating.comment || <span className="italic text-muted-foreground/50">No comment</span>}
                </div>
            ),
        },
        {
            key: "created",
            header: "Date",
            cell: (rating) => <div className="text-sm font-medium text-muted-foreground whitespace-nowrap">{formatDate(rating.createdAt)}</div>,
        },
        {
            key: "actions",
            header: "Actions",
            className: "w-[100px]",
            cell: (rating) => (
                <div onClick={(e) => e.stopPropagation()}>
                    <Button
                        size="sm"
                        variant="destructive"
                        className="font-semibold text-xs shadow-sm"
                        onClick={() => setConfirmDialog({ open: true, rating })}
                        disabled={deleteMutation.isPending}
                    >
                        <Trash2 className="mr-1.5 h-3.5 w-3.5" />
                        Delete
                    </Button>
                </div>
            ),
        },
    ]

    if (error) {
        return (
            <div className="space-y-4 animate-in fade-in duration-500">
                <h1 className="text-4xl font-extrabold tracking-tight">Ratings</h1>
                <div className="rounded-xl border border-destructive/50 bg-destructive/10 p-6 text-destructive flex items-center shadow-sm">
                    <AlertCircle className="w-6 h-6 mr-3" />
                    <span className="font-semibold text-lg">Failed to load ratings. Please try again.</span>
                </div>
            </div>
        )
    }

    return (
        <div className="space-y-8 animate-in fade-in slide-in-from-bottom-8 duration-700 pb-10">
            <div className="flex flex-col gap-4 md:flex-row md:items-center justify-between">
                <div className="flex items-center gap-4">
                    <div className="bg-amber-500/10 p-3 rounded-2xl border border-amber-500/20 shadow-sm hidden sm:block">
                        <Star className="w-8 h-8 text-amber-500" />
                    </div>
                    <div>
                        <h1 className="text-4xl font-extrabold tracking-tight text-foreground/90 leading-tight">Ratings & Reviews</h1>
                        <p className="text-muted-foreground mt-1 text-lg font-medium">
                            Monitor and manage user ratings. Remove abusive or inappropriate reviews.
                        </p>
                    </div>
                </div>
            </div>

            <Card className="border-border/50 shadow-lg bg-card/60 backdrop-blur-xl dark:shadow-none dark:border-white/10 overflow-hidden">
                <CardHeader className="bg-muted/30 border-b border-border/40 pb-5 pt-6 px-6">
                    <div className="flex flex-col sm:flex-row gap-4 items-center justify-between">
                        <h2 className="text-xl font-bold flex items-center">
                            <Star className="w-5 h-5 mr-3 text-amber-500" />
                            All Ratings
                        </h2>
                        <div className="text-sm font-semibold bg-background/80 px-3 py-1.5 rounded-full border border-border/50 shadow-sm">
                            <span className="text-muted-foreground">Total:</span> <span className="text-foreground ml-1">{data?.meta?.total || 0}</span>
                        </div>
                    </div>
                </CardHeader>

                <CardContent className="p-0">
                    <div className="overflow-x-auto">
                        <DataTable
                            columns={columns}
                            data={data?.data || []}
                            page={page}
                            totalPages={data?.meta.totalPages || 0}
                            total={data?.meta.total || 0}
                            onPageChange={handlePageChange}
                            pageSize={limit}
                            loading={isLoading}
                            emptyMessage="No ratings found."
                        />
                    </div>
                </CardContent>
            </Card>

            <ConfirmDialog
                open={confirmDialog.open}
                onOpenChange={(open) => setConfirmDialog((prev) => ({ ...prev, open }))}
                title="Delete Rating"
                description="Are you sure you want to delete this rating? This action cannot be undone."
                variant="destructive"
                onConfirm={() => {
                    if (confirmDialog.rating) {
                        deleteMutation.mutate(confirmDialog.rating._id)
                    }
                }}
                loading={deleteMutation.isPending}
            />
        </div>
    )
}
